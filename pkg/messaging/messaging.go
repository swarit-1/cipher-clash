package messaging

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/swarit-1/cipher-clash/pkg/config"
	"github.com/swarit-1/cipher-clash/pkg/logger"
)

// EventType represents different event types
type EventType string

const (
	EventMatchCreated     EventType = "match.created"
	EventMatchCompleted   EventType = "match.completed"
	EventAchievementUnlocked EventType = "achievement.unlocked"
	EventPlayerJoinedQueue EventType = "queue.player_joined"
	EventPlayerLeftQueue  EventType = "queue.player_left"
)

// Event represents a message event
type Event struct {
	Type      EventType              `json:"type"`
	Timestamp time.Time              `json:"timestamp"`
	Data      map[string]interface{} `json:"data"`
}

// Publisher handles publishing messages to RabbitMQ
type Publisher struct {
	conn    *amqp.Connection
	channel *amqp.Channel
	log     *logger.Logger
}

// Subscriber handles consuming messages from RabbitMQ
type Subscriber struct {
	conn    *amqp.Connection
	channel *amqp.Channel
	log     *logger.Logger
}

// NewPublisher creates a new message publisher
func NewPublisher(cfg config.RabbitMQConfig, log *logger.Logger) (*Publisher, error) {
	conn, err := amqp.Dial(cfg.URL)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to RabbitMQ: %w", err)
	}

	channel, err := conn.Channel()
	if err != nil {
		conn.Close()
		return nil, fmt.Errorf("failed to open channel: %w", err)
	}

	log.Info("RabbitMQ Publisher connected successfully")

	return &Publisher{
		conn:    conn,
		channel: channel,
		log:     log,
	}, nil
}

// Publish publishes an event to a specific exchange
func (p *Publisher) Publish(ctx context.Context, exchange string, routingKey string, event Event) error {
	event.Timestamp = time.Now().UTC()

	body, err := json.Marshal(event)
	if err != nil {
		return fmt.Errorf("failed to marshal event: %w", err)
	}

	err = p.channel.PublishWithContext(
		ctx,
		exchange,   // exchange
		routingKey, // routing key
		false,      // mandatory
		false,      // immediate
		amqp.Publishing{
			ContentType: "application/json",
			Body:        body,
			Timestamp:   event.Timestamp,
		},
	)

	if err != nil {
		return fmt.Errorf("failed to publish message: %w", err)
	}

	p.log.Debug("Published event", map[string]interface{}{
		"type":        event.Type,
		"exchange":    exchange,
		"routing_key": routingKey,
	})

	return nil
}

// DeclareExchange declares an exchange
func (p *Publisher) DeclareExchange(name, kind string) error {
	return p.channel.ExchangeDeclare(
		name,
		kind,  // type: direct, fanout, topic, headers
		true,  // durable
		false, // auto-deleted
		false, // internal
		false, // no-wait
		nil,   // arguments
	)
}

// Close closes the publisher connection
func (p *Publisher) Close() error {
	p.log.Info("Closing RabbitMQ Publisher connection")
	if err := p.channel.Close(); err != nil {
		return err
	}
	return p.conn.Close()
}

// NewSubscriber creates a new message subscriber
func NewSubscriber(cfg config.RabbitMQConfig, log *logger.Logger) (*Subscriber, error) {
	conn, err := amqp.Dial(cfg.URL)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to RabbitMQ: %w", err)
	}

	channel, err := conn.Channel()
	if err != nil {
		conn.Close()
		return nil, fmt.Errorf("failed to open channel: %w", err)
	}

	log.Info("RabbitMQ Subscriber connected successfully")

	return &Subscriber{
		conn:    conn,
		channel: channel,
		log:     log,
	}, nil
}

// Subscribe subscribes to a queue and processes messages
func (s *Subscriber) Subscribe(queueName string, handler func(Event) error) error {
	msgs, err := s.channel.Consume(
		queueName,
		"",    // consumer tag
		false, // auto-ack (manual ack for reliability)
		false, // exclusive
		false, // no-local
		false, // no-wait
		nil,   // args
	)
	if err != nil {
		return fmt.Errorf("failed to register consumer: %w", err)
	}

	s.log.Info("Subscribed to queue", map[string]interface{}{
		"queue": queueName,
	})

	go func() {
		for msg := range msgs {
			var event Event
			if err := json.Unmarshal(msg.Body, &event); err != nil {
				s.log.Error("Failed to unmarshal message", map[string]interface{}{
					"error": err.Error(),
				})
				msg.Nack(false, false) // Don't requeue
				continue
			}

			if err := handler(event); err != nil {
				s.log.Error("Handler error", map[string]interface{}{
					"error": err.Error(),
					"type":  event.Type,
				})
				msg.Nack(false, true) // Requeue for retry
				continue
			}

			msg.Ack(false)
			s.log.Debug("Message processed successfully", map[string]interface{}{
				"type": event.Type,
			})
		}
	}()

	return nil
}

// DeclareQueue declares a queue
func (s *Subscriber) DeclareQueue(name string) (amqp.Queue, error) {
	return s.channel.QueueDeclare(
		name,
		true,  // durable
		false, // delete when unused
		false, // exclusive
		false, // no-wait
		nil,   // arguments
	)
}

// BindQueue binds a queue to an exchange
func (s *Subscriber) BindQueue(queueName, exchangeName, routingKey string) error {
	return s.channel.QueueBind(
		queueName,
		routingKey,
		exchangeName,
		false,
		nil,
	)
}

// Close closes the subscriber connection
func (s *Subscriber) Close() error {
	s.log.Info("Closing RabbitMQ Subscriber connection")
	if err := s.channel.Close(); err != nil {
		return err
	}
	return s.conn.Close()
}

// Helper functions for common exchanges
const (
	ExchangeMatches      = "matches"
	ExchangeAchievements = "achievements"
	ExchangeQueue        = "matchmaking"
)

// InitializeExchanges sets up common exchanges
func InitializeExchanges(publisher *Publisher) error {
	exchanges := map[string]string{
		ExchangeMatches:      "topic",
		ExchangeAchievements: "fanout",
		ExchangeQueue:        "topic",
	}

	for name, kind := range exchanges {
		if err := publisher.DeclareExchange(name, kind); err != nil {
			return fmt.Errorf("failed to declare exchange %s: %w", name, err)
		}
	}

	return nil
}
