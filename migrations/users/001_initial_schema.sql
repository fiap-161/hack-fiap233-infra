-- Migration: 001_initial_schema
-- Database: usersdb (RDS do serviço Users)
-- Description: Tabela de usuários para registro, login e identificação.
-- Applied by: scripts/run_migrations.sh or manually via psql

-- Tabela principal de usuários
CREATE TABLE IF NOT EXISTS users (
    id            SERIAL PRIMARY KEY,
    name          TEXT NOT NULL,
    email         TEXT NOT NULL,
    password_hash TEXT NOT NULL DEFAULT ''
);

-- Índice único para login e unicidade de e-mail
CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique ON users (email);

-- Garante coluna password_hash em tabelas criadas antes desta migration
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash TEXT NOT NULL DEFAULT '';
