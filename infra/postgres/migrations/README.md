# Database Migrations

This directory contains versioned database migrations for Cipher Clash V2.0.

## Migration Naming Convention

Migrations follow the pattern: `{version}_{description}.{up|down}.sql`

- **version**: Sequential number with leading zeros (e.g., 001, 002)
- **description**: Snake_case description of the migration
- **up**: Forward migration (applies changes)
- **down**: Rollback migration (reverts changes)

## Available Migrations

1. **001_initial_schema**: Creates the complete V2.0 database schema with all tables, indexes, triggers, and seed data

## Running Migrations

### Using golang-migrate CLI

Install golang-migrate:
```bash
go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
```

Apply migrations:
```bash
migrate -path infra/postgres/migrations -database "postgres://postgres:password@localhost:5432/cipher_clash?sslmode=disable" up
```

Rollback last migration:
```bash
migrate -path infra/postgres/migrations -database "postgres://postgres:password@localhost:5432/cipher_clash?sslmode=disable" down 1
```

### Using Docker

The schema_v2.sql is automatically loaded when the PostgreSQL container starts via docker-compose.

## Adding New Migrations

1. Create new up/down migration files with the next version number
2. Write forward migration in `{version}_{description}.up.sql`
3. Write rollback in `{version}_{description}.down.sql`
4. Test both up and down migrations
5. Update this README with the new migration description

## Best Practices

- Always create both up and down migrations
- Test rollbacks before deploying
- Never modify existing migrations that have been deployed
- Use transactions where possible
- Add comments explaining complex migrations
- Include seed data only in appropriate migrations
