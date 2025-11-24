package repository

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/pkg/db"
	"github.com/swarit-1/cipher-clash/pkg/errors"
)

// User represents a user model
type User struct {
	ID              uuid.UUID  `json:"id"`
	Username        string     `json:"username"`
	Email           string     `json:"email"`
	PasswordHash    string     `json:"-"` // Never expose password hash
	DisplayName     sql.NullString `json:"display_name"`
	AvatarURL       sql.NullString `json:"avatar_url"`
	Title           sql.NullString `json:"title"`
	Region          string     `json:"region"`
	Level           int        `json:"level"`
	XP              int64      `json:"xp"`
	TotalGames      int        `json:"total_games"`
	Wins            int        `json:"wins"`
	Losses          int        `json:"losses"`
	WinStreak       int        `json:"win_streak"`
	BestWinStreak   int        `json:"best_win_streak"`
	EloRating       int        `json:"elo_rating"`
	RatingDeviation float64    `json:"rating_deviation"`
	Volatility      float64    `json:"volatility"`
	RankTier        string     `json:"rank_tier"`
	PuzzlesSolved   int        `json:"puzzles_solved"`
	FastestSolveMS  sql.NullInt32 `json:"fastest_solve_ms"`
	IsVerified      bool       `json:"is_verified"`
	IsBanned        bool       `json:"is_banned"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

// UserRepository handles user database operations
type UserRepository struct {
	db *db.DB
}

// NewUserRepository creates a new user repository
func NewUserRepository(database *db.DB) *UserRepository {
	return &UserRepository{db: database}
}

// Create creates a new user
func (r *UserRepository) Create(ctx context.Context, user *User) error {
	query := `
		INSERT INTO users (
			username, email, password_hash, region, display_name
		) VALUES ($1, $2, $3, $4, $5)
		RETURNING id, created_at, updated_at, level, xp, elo_rating, rank_tier
	`

	err := r.db.QueryRowContext(
		ctx,
		query,
		user.Username,
		user.Email,
		user.PasswordHash,
		user.Region,
		user.DisplayName,
	).Scan(
		&user.ID,
		&user.CreatedAt,
		&user.UpdatedAt,
		&user.Level,
		&user.XP,
		&user.EloRating,
		&user.RankTier,
	)

	if err != nil {
		// Check for unique constraint violations
		if err.Error() == `pq: duplicate key value violates unique constraint "users_username_key"` {
			return errors.NewUserAlreadyExistsError("username")
		}
		if err.Error() == `pq: duplicate key value violates unique constraint "users_email_key"` {
			return errors.NewUserAlreadyExistsError("email")
		}
		return errors.NewDatabaseError(err)
	}

	return nil
}

// FindByID retrieves a user by ID
func (r *UserRepository) FindByID(ctx context.Context, id uuid.UUID) (*User, error) {
	user := &User{}
	query := `
		SELECT
			id, username, email, password_hash, display_name, avatar_url, title, region,
			level, xp, total_games, wins, losses, win_streak, best_win_streak,
			elo_rating, rating_deviation, volatility, rank_tier, puzzles_solved,
			fastest_solve_ms, is_verified, is_banned, created_at, updated_at
		FROM users
		WHERE id = $1
	`

	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&user.ID, &user.Username, &user.Email, &user.PasswordHash,
		&user.DisplayName, &user.AvatarURL, &user.Title, &user.Region,
		&user.Level, &user.XP, &user.TotalGames, &user.Wins, &user.Losses,
		&user.WinStreak, &user.BestWinStreak, &user.EloRating,
		&user.RatingDeviation, &user.Volatility, &user.RankTier,
		&user.PuzzlesSolved, &user.FastestSolveMS, &user.IsVerified,
		&user.IsBanned, &user.CreatedAt, &user.UpdatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, errors.NewUserNotFoundError()
		}
		return nil, errors.NewDatabaseError(err)
	}

	return user, nil
}

// FindByEmail retrieves a user by email
func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
	user := &User{}
	query := `
		SELECT
			id, username, email, password_hash, display_name, avatar_url, title, region,
			level, xp, total_games, wins, losses, win_streak, best_win_streak,
			elo_rating, rating_deviation, volatility, rank_tier, puzzles_solved,
			fastest_solve_ms, is_verified, is_banned, created_at, updated_at
		FROM users
		WHERE email = $1
	`

	err := r.db.QueryRowContext(ctx, query, email).Scan(
		&user.ID, &user.Username, &user.Email, &user.PasswordHash,
		&user.DisplayName, &user.AvatarURL, &user.Title, &user.Region,
		&user.Level, &user.XP, &user.TotalGames, &user.Wins, &user.Losses,
		&user.WinStreak, &user.BestWinStreak, &user.EloRating,
		&user.RatingDeviation, &user.Volatility, &user.RankTier,
		&user.PuzzlesSolved, &user.FastestSolveMS, &user.IsVerified,
		&user.IsBanned, &user.CreatedAt, &user.UpdatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, errors.NewUserNotFoundError()
		}
		return nil, errors.NewDatabaseError(err)
	}

	return user, nil
}

// FindByUsername retrieves a user by username
func (r *UserRepository) FindByUsername(ctx context.Context, username string) (*User, error) {
	user := &User{}
	query := `
		SELECT
			id, username, email, password_hash, display_name, avatar_url, title, region,
			level, xp, total_games, wins, losses, win_streak, best_win_streak,
			elo_rating, rating_deviation, volatility, rank_tier, puzzles_solved,
			fastest_solve_ms, is_verified, is_banned, created_at, updated_at
		FROM users
		WHERE username = $1
	`

	err := r.db.QueryRowContext(ctx, query, username).Scan(
		&user.ID, &user.Username, &user.Email, &user.PasswordHash,
		&user.DisplayName, &user.AvatarURL, &user.Title, &user.Region,
		&user.Level, &user.XP, &user.TotalGames, &user.Wins, &user.Losses,
		&user.WinStreak, &user.BestWinStreak, &user.EloRating,
		&user.RatingDeviation, &user.Volatility, &user.RankTier,
		&user.PuzzlesSolved, &user.FastestSolveMS, &user.IsVerified,
		&user.IsBanned, &user.CreatedAt, &user.UpdatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			return nil, errors.NewUserNotFoundError()
		}
		return nil, errors.NewDatabaseError(err)
	}

	return user, nil
}

// Update updates a user
func (r *UserRepository) Update(ctx context.Context, user *User) error {
	query := `
		UPDATE users SET
			display_name = $2,
			avatar_url = $3,
			region = $4,
			level = $5,
			xp = $6,
			elo_rating = $7,
			total_games = $8,
			wins = $9,
			losses = $10,
			win_streak = $11,
			best_win_streak = $12,
			puzzles_solved = $13,
			updated_at = NOW()
		WHERE id = $1
	`

	result, err := r.db.ExecContext(
		ctx,
		query,
		user.ID,
		user.DisplayName,
		user.AvatarURL,
		user.Region,
		user.Level,
		user.XP,
		user.EloRating,
		user.TotalGames,
		user.Wins,
		user.Losses,
		user.WinStreak,
		user.BestWinStreak,
		user.PuzzlesSolved,
	)

	if err != nil {
		return errors.NewDatabaseError(err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return errors.NewDatabaseError(err)
	}

	if rowsAffected == 0 {
		return errors.NewUserNotFoundError()
	}

	return nil
}

// UpdateELO updates user's ELO rating
func (r *UserRepository) UpdateELO(ctx context.Context, userID uuid.UUID, newELO int, eloChange int) error {
	query := `
		UPDATE users
		SET elo_rating = $2, updated_at = NOW()
		WHERE id = $1
	`

	result, err := r.db.ExecContext(ctx, query, userID, newELO)
	if err != nil {
		return errors.NewDatabaseError(err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return errors.NewDatabaseError(err)
	}

	if rowsAffected == 0 {
		return errors.NewUserNotFoundError()
	}

	return nil
}

// UpdateStats updates user game statistics
func (r *UserRepository) UpdateStats(ctx context.Context, userID uuid.UUID, won bool) error {
	query := `
		UPDATE users SET
			total_games = total_games + 1,
			wins = CASE WHEN $2 THEN wins + 1 ELSE wins END,
			losses = CASE WHEN $2 THEN losses ELSE losses + 1 END,
			win_streak = CASE WHEN $2 THEN win_streak + 1 ELSE 0 END,
			best_win_streak = CASE
				WHEN $2 AND (win_streak + 1) > best_win_streak
				THEN win_streak + 1
				ELSE best_win_streak
			END,
			updated_at = NOW()
		WHERE id = $1
	`

	_, err := r.db.ExecContext(ctx, query, userID, won)
	if err != nil {
		return errors.NewDatabaseError(err)
	}

	return nil
}

// GetLeaderboard retrieves top players
func (r *UserRepository) GetLeaderboard(ctx context.Context, limit, offset int) ([]*User, error) {
	query := `
		SELECT
			id, username, display_name, avatar_url, level, elo_rating, rank_tier,
			total_games, wins, losses, win_streak, best_win_streak
		FROM users
		WHERE is_banned = FALSE AND total_games >= 10
		ORDER BY elo_rating DESC
		LIMIT $1 OFFSET $2
	`

	rows, err := r.db.QueryContext(ctx, query, limit, offset)
	if err != nil {
		return nil, errors.NewDatabaseError(err)
	}
	defer rows.Close()

	var users []*User
	for rows.Next() {
		user := &User{}
		err := rows.Scan(
			&user.ID, &user.Username, &user.DisplayName, &user.AvatarURL,
			&user.Level, &user.EloRating, &user.RankTier, &user.TotalGames,
			&user.Wins, &user.Losses, &user.WinStreak, &user.BestWinStreak,
		)
		if err != nil {
			return nil, errors.NewDatabaseError(err)
		}
		users = append(users, user)
	}

	return users, nil
}

// Delete deletes a user (soft delete by marking as banned)
func (r *UserRepository) Delete(ctx context.Context, id uuid.UUID) error {
	query := `UPDATE users SET is_banned = TRUE WHERE id = $1`
	_, err := r.db.ExecContext(ctx, query, id)
	if err != nil {
		return errors.NewDatabaseError(err)
	}
	return nil
}

// UpdateLastLogin updates the user's last login timestamp
func (r *UserRepository) UpdateLastLogin(ctx context.Context, userID uuid.UUID) error {
	query := `UPDATE users SET last_login_at = NOW() WHERE id = $1`
	_, err := r.db.ExecContext(ctx, query, userID)
	return err
}
