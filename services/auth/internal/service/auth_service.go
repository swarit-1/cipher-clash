package service

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/pkg/auth"
	"github.com/swarit-1/cipher-clash/pkg/cache"
	"github.com/swarit-1/cipher-clash/pkg/errors"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/pkg/repository"
)

// AuthService handles authentication business logic
type AuthService struct {
	userRepo   *repository.UserRepository
	jwtManager *auth.JWTManager
	cache      *cache.Cache
	log        *logger.Logger
}

// NewAuthService creates a new auth service
func NewAuthService(
	userRepo *repository.UserRepository,
	jwtManager *auth.JWTManager,
	cache *cache.Cache,
	log *logger.Logger,
) *AuthService {
	return &AuthService{
		userRepo:   userRepo,
		jwtManager: jwtManager,
		cache:      cache,
		log:        log,
	}
}

// RegisterRequest represents registration input
type RegisterRequest struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
	Region   string `json:"region"`
}

// LoginRequest represents login input
type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// AuthResponse represents authentication response
type AuthResponse struct {
	User         *UserDTO `json:"user"`
	AccessToken  string   `json:"access_token"`
	RefreshToken string   `json:"refresh_token"`
	ExpiresIn    int64    `json:"expires_in"`
}

// UserDTO represents user data transfer object
type UserDTO struct {
	ID          string `json:"id"`
	Username    string `json:"username"`
	Email       string `json:"email"`
	DisplayName string `json:"display_name,omitempty"`
	AvatarURL   string `json:"avatar_url,omitempty"`
	Level       int    `json:"level"`
	XP          int64  `json:"xp"`
	EloRating   int    `json:"elo_rating"`
	RankTier    string `json:"rank_tier"`
	Region      string `json:"region"`
}

// Register creates a new user account
func (s *AuthService) Register(ctx context.Context, req *RegisterRequest) (*AuthResponse, error) {
	// Validate input
	if err := s.validateRegisterRequest(req); err != nil {
		return nil, err
	}

	// Check rate limit
	rateLimitKey := fmt.Sprintf("register:%s", req.Email)
	allowed, err := s.cache.RateLimitCheck(ctx, rateLimitKey, 5, cache.TTLRateLimit)
	if err != nil {
		s.log.Error("Rate limit check failed", map[string]interface{}{"error": err.Error()})
	}
	if !allowed {
		return nil, errors.NewRateLimitError()
	}

	// Hash password
	passwordHash, err := auth.HashPassword(req.Password)
	if err != nil {
		return nil, errors.NewInternalServerError(err)
	}

	// Set default region
	region := req.Region
	if region == "" {
		region = "US"
	}

	// Create user
	user := &repository.User{
		Username:     req.Username,
		Email:        req.Email,
		PasswordHash: passwordHash,
		Region:       region,
		DisplayName:  sql.NullString{String: req.Username, Valid: true},
	}

	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, err
	}

	s.log.Info("User registered successfully", map[string]interface{}{
		"user_id":  user.ID.String(),
		"username": user.Username,
	})

	// Generate tokens
	tokens, err := s.jwtManager.GenerateTokenPair(user.ID.String(), user.Username)
	if err != nil {
		return nil, errors.NewInternalServerError(err)
	}

	// Cache session
	sessionKey := fmt.Sprintf("session:%s", user.ID.String())
	s.cache.Set(ctx, sessionKey, map[string]interface{}{
		"user_id":  user.ID.String(),
		"username": user.Username,
	}, cache.TTLSession)

	return &AuthResponse{
		User:         s.toUserDTO(user),
		AccessToken:  tokens.AccessToken,
		RefreshToken: tokens.RefreshToken,
		ExpiresIn:    tokens.ExpiresIn,
	}, nil
}

// Login authenticates a user
func (s *AuthService) Login(ctx context.Context, req *LoginRequest) (*AuthResponse, error) {
	// Rate limiting
	rateLimitKey := fmt.Sprintf("login:%s", req.Email)
	allowed, err := s.cache.RateLimitCheck(ctx, rateLimitKey, 5, cache.TTLRateLimit)
	if err != nil {
		s.log.Error("Rate limit check failed", map[string]interface{}{"error": err.Error()})
	}
	if !allowed {
		return nil, errors.NewRateLimitError()
	}

	// Find user by email
	user, err := s.userRepo.FindByEmail(ctx, req.Email)
	if err != nil {
		return nil, errors.NewInvalidCredentialsError()
	}

	// Check if banned
	if user.IsBanned {
		return nil, errors.NewForbiddenError("Account is banned")
	}

	// Verify password
	if err := auth.ComparePassword(user.PasswordHash, req.Password); err != nil {
		return nil, errors.NewInvalidCredentialsError()
	}

	// Update last login
	s.userRepo.UpdateLastLogin(ctx, user.ID)

	s.log.Info("User logged in successfully", map[string]interface{}{
		"user_id":  user.ID.String(),
		"username": user.Username,
	})

	// Generate tokens
	tokens, err := s.jwtManager.GenerateTokenPair(user.ID.String(), user.Username)
	if err != nil {
		return nil, errors.NewInternalServerError(err)
	}

	// Cache session
	sessionKey := fmt.Sprintf("session:%s", user.ID.String())
	s.cache.Set(ctx, sessionKey, map[string]interface{}{
		"user_id":  user.ID.String(),
		"username": user.Username,
	}, cache.TTLSession)

	return &AuthResponse{
		User:         s.toUserDTO(user),
		AccessToken:  tokens.AccessToken,
		RefreshToken: tokens.RefreshToken,
		ExpiresIn:    tokens.ExpiresIn,
	}, nil
}

// RefreshToken generates a new access token from refresh token
func (s *AuthService) RefreshToken(ctx context.Context, refreshToken string) (*auth.TokenPair, error) {
	// Validate refresh token
	claims, err := s.jwtManager.ValidateToken(refreshToken, auth.RefreshToken)
	if err != nil {
		return nil, errors.NewUnauthorizedError("Invalid refresh token")
	}

	// Check if user still exists and is not banned
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, errors.NewUnauthorizedError("Invalid user ID")
	}

	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return nil, errors.NewUnauthorizedError("User not found")
	}

	if user.IsBanned {
		return nil, errors.NewForbiddenError("Account is banned")
	}

	// Generate new token pair
	tokens, err := s.jwtManager.GenerateTokenPair(user.ID.String(), user.Username)
	if err != nil {
		return nil, errors.NewInternalServerError(err)
	}

	s.log.Debug("Token refreshed", map[string]interface{}{
		"user_id": user.ID.String(),
	})

	return tokens, nil
}

// ValidateToken validates an access token
func (s *AuthService) ValidateToken(ctx context.Context, accessToken string) (*auth.Claims, error) {
	claims, err := s.jwtManager.ValidateToken(accessToken, auth.AccessToken)
	if err != nil {
		return nil, errors.NewUnauthorizedError("Invalid access token")
	}

	return claims, nil
}

// GetUser retrieves user by ID
func (s *AuthService) GetUser(ctx context.Context, userID uuid.UUID) (*UserDTO, error) {
	// Try cache first
	cacheKey := fmt.Sprintf("user:%s", userID.String())
	var cachedUser UserDTO
	if err := s.cache.Get(ctx, cacheKey, &cachedUser); err == nil {
		return &cachedUser, nil
	}

	// Fetch from database
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return nil, err
	}

	dto := s.toUserDTO(user)

	// Cache for future requests
	s.cache.Set(ctx, cacheKey, dto, cache.TTLUserProfile)

	return dto, nil
}

// UpdateProfile updates user profile
func (s *AuthService) UpdateProfile(ctx context.Context, userID uuid.UUID, displayName, avatarURL, region string) (*UserDTO, error) {
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return nil, err
	}

	// Update fields
	if displayName != "" {
		user.DisplayName = sql.NullString{String: displayName, Valid: true}
	}
	if avatarURL != "" {
		user.AvatarURL = sql.NullString{String: avatarURL, Valid: true}
	}
	if region != "" {
		user.Region = region
	}

	if err := s.userRepo.Update(ctx, user); err != nil {
		return nil, err
	}

	// Invalidate cache
	cacheKey := fmt.Sprintf("user:%s", userID.String())
	s.cache.Delete(ctx, cacheKey)

	s.log.Info("Profile updated", map[string]interface{}{
		"user_id": userID.String(),
	})

	return s.toUserDTO(user), nil
}

// Logout invalidates user session
func (s *AuthService) Logout(ctx context.Context, userID uuid.UUID) error {
	sessionKey := fmt.Sprintf("session:%s", userID.String())
	return s.cache.Delete(ctx, sessionKey)
}

// Helper functions

func (s *AuthService) validateRegisterRequest(req *RegisterRequest) error {
	if req.Username == "" {
		return errors.NewInvalidInputError("Username is required")
	}
	if len(req.Username) < 3 || len(req.Username) > 50 {
		return errors.NewInvalidInputError("Username must be between 3 and 50 characters")
	}
	if req.Email == "" {
		return errors.NewInvalidInputError("Email is required")
	}
	if req.Password == "" {
		return errors.NewInvalidInputError("Password is required")
	}
	if err := auth.ValidatePasswordStrength(req.Password); err != nil {
		return errors.NewInvalidInputError(err.Error())
	}
	return nil
}

func (s *AuthService) toUserDTO(user *repository.User) *UserDTO {
	dto := &UserDTO{
		ID:        user.ID.String(),
		Username:  user.Username,
		Email:     user.Email,
		Level:     user.Level,
		XP:        user.XP,
		EloRating: user.EloRating,
		RankTier:  user.RankTier,
		Region:    user.Region,
	}

	if user.DisplayName.Valid {
		dto.DisplayName = user.DisplayName.String
	}
	if user.AvatarURL.Valid {
		dto.AvatarURL = user.AvatarURL.String
	}

	return dto
}
