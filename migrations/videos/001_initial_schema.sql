-- Migration: 001_initial_schema
-- Database: videosdb (RDS do serviço Videos)
-- Description: Tabela de vídeos para metadados e status (evolução futura: status, user_id, storage_key, etc.)
-- Applied by: scripts/run_migrations.sh or manually via psql

-- Tabela principal de vídeos (schema mínimo alinhado ao serviço atual)
CREATE TABLE IF NOT EXISTS videos (
    id          SERIAL PRIMARY KEY,
    title       TEXT NOT NULL,
    description TEXT NOT NULL
);

-- Índice para listagens ordenadas
CREATE INDEX IF NOT EXISTS videos_id_idx ON videos (id);
