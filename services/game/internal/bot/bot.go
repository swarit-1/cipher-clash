// Package bot implements a server-side opponent that plays matches through
// the same Participant interface and message protocol as a human client,
// so the room logic is completely opponent-agnostic.
package bot

import (
	"encoding/json"
	"math/rand"
	"sync"
	"time"

	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/game/internal/room"
)

const (
	progressInterval = 2 * time.Second
	wrongSubmitOdds  = 0.12 // chance of fumbling a wrong answer first
)

// Bot is a room participant that "solves" puzzles on a difficulty- and
// rating-scaled timer, emitting PROGRESS like a human would.
type Bot struct {
	room        *room.Room
	info        room.PlayerInfo
	opponentELO int
	solutions   map[int]string // puzzle index -> plaintext

	inbox  chan room.Envelope
	closed chan struct{}
	once   sync.Once
	log    *logger.Logger
	rng    *rand.Rand
}

// New creates a bot participant for the given room. It knows the puzzle
// solutions (it is the server, after all) but paces itself to feel human.
func New(r *room.Room, info room.PlayerInfo, opponentELO int, puzzles []room.Puzzle, log *logger.Logger) *Bot {
	solutions := make(map[int]string, len(puzzles))
	for i, p := range puzzles {
		solutions[i] = p.Plaintext
	}
	b := &Bot{
		room:        r,
		info:        info,
		opponentELO: opponentELO,
		solutions:   solutions,
		inbox:       make(chan room.Envelope, 64),
		closed:      make(chan struct{}),
		log:         log,
		rng:         rand.New(rand.NewSource(time.Now().UnixNano())),
	}
	go b.run()
	return b
}

// Send implements room.Participant.
func (b *Bot) Send(env room.Envelope) {
	select {
	case b.inbox <- env:
	case <-b.closed:
	default:
	}
}

// Close implements room.Participant.
func (b *Bot) Close() {
	b.once.Do(func() { close(b.closed) })
}

// run reacts to room messages exactly like a client would.
func (b *Bot) run() {
	var (
		solveTimer    *time.Timer
		progressTick  *time.Ticker
		solveDeadline time.Time
		solveStart    time.Time
		currentIndex  = -1
		fumbled       bool
	)
	stopTimers := func() {
		if solveTimer != nil {
			solveTimer.Stop()
		}
		if progressTick != nil {
			progressTick.Stop()
		}
	}
	defer stopTimers()

	// Channels read in the select need stable references.
	timerC := func() <-chan time.Time {
		if solveTimer == nil {
			return nil
		}
		return solveTimer.C
	}
	tickC := func() <-chan time.Time {
		if progressTick == nil {
			return nil
		}
		return progressTick.C
	}

	startPuzzle := func(index, difficulty int) {
		stopTimers()
		currentIndex = index
		fumbled = false
		d := b.solveDuration(difficulty)
		solveStart = time.Now()
		solveDeadline = solveStart.Add(d)
		solveTimer = time.NewTimer(d)
		progressTick = time.NewTicker(progressInterval)
		b.log.Debug("Bot started puzzle", map[string]interface{}{
			"bot": b.info.Username, "puzzle": index, "eta_s": int(d.Seconds()),
		})
	}

	for {
		select {
		case <-b.closed:
			return

		case env := <-b.inbox:
			switch env.Type {
			case room.TypePuzzleSet:
				var p room.PuzzleSetPayload
				if err := json.Unmarshal(env.Payload, &p); err == nil {
					startPuzzle(p.Puzzle.Index, p.Puzzle.Difficulty)
				}
			case room.TypeSubmitResult:
				var res room.SubmitResultPayload
				if err := json.Unmarshal(env.Payload, &res); err == nil && !res.Correct {
					// Fumbled: take a moment, then submit the real answer.
					retry := time.Duration(3+b.rng.Intn(5)) * time.Second
					solveTimer = time.NewTimer(retry)
					solveDeadline = time.Now().Add(retry)
				}
			case room.TypeMatchEnd:
				b.Close()
				return
			}

		case <-tickC():
			if currentIndex < 0 {
				continue
			}
			total := solveDeadline.Sub(solveStart)
			progress := 0.0
			if total > 0 {
				progress = float64(time.Since(solveStart)) / float64(total)
			}
			if progress > 0.95 {
				progress = 0.95
			}
			b.room.HandleMessage(b.info.UserID, room.NewEnvelope(room.TypeProgress, room.ProgressPayload{
				Progress: progress,
			}))

		case <-timerC():
			if currentIndex < 0 {
				continue
			}
			solution := b.solutions[currentIndex]
			if !fumbled && b.rng.Float64() < wrongSubmitOdds {
				fumbled = true
				solution = "WRONG GUESS " + solution[:min(4, len(solution))]
			}
			b.room.HandleMessage(b.info.UserID, room.NewEnvelope(room.TypeSubmit, room.SubmitPayload{
				PuzzleIndex: currentIndex,
				Solution:    solution,
			}))
		}
	}
}

// solveDuration models how long the bot "thinks": a base scaled by puzzle
// difficulty and the bot's rating relative to its opponent, with ±30%
// jitter — strong enough to pressure, beatable by a focused player.
func (b *Bot) solveDuration(difficulty int) time.Duration {
	base := 18.0 + float64(difficulty)*9.0 // seconds

	// Rating handicap: a bot 200 below its opponent is ~20% slower; a bot
	// 200 above is ~15% faster, clamped to sane bounds.
	delta := float64(b.opponentELO - b.info.ELO)
	factor := 1.0 + delta/1000.0
	if factor < 0.7 {
		factor = 0.7
	}
	if factor > 1.5 {
		factor = 1.5
	}

	jitter := 0.7 + b.rng.Float64()*0.6 // 0.7–1.3
	return time.Duration(base*factor*jitter) * time.Second
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
