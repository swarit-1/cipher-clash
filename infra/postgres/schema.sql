-- Users Table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    rating INT DEFAULT 1200, -- Glicko-2 rating
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seasons Table
CREATE TABLE seasons (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT FALSE
);

-- Puzzles Table
CREATE TABLE puzzles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(50) NOT NULL, -- 'VIGENERE', 'CAESAR', 'RAIL_FENCE'
    difficulty_level INT NOT NULL,
    encrypted_text TEXT NOT NULL,
    plain_text TEXT NOT NULL,
    config JSONB, -- Store specific cipher params (e.g., key)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Matches Table
CREATE TABLE matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player1_id UUID REFERENCES users(id),
    player2_id UUID REFERENCES users(id),
    winner_id UUID REFERENCES users(id),
    puzzle_id UUID REFERENCES puzzles(id),
    season_id INT REFERENCES seasons(id),
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ended_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'IN_PROGRESS' -- 'IN_PROGRESS', 'COMPLETED', 'ABORTED'
);
