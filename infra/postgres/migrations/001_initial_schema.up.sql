-- Migration: 001 - Initial V2.0 Schema
-- This migration creates the complete V2.0 schema from scratch

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Import the complete V2.0 schema
-- Note: This assumes schema_v2.sql is available
-- In production, copy the full schema here or use a migration tool like golang-migrate

-- For now, we'll create a minimal working schema that can be expanded
-- The full schema is in schema_v2.sql

\i /docker-entrypoint-initdb.d/schema_v2.sql
