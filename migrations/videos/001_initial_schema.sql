-- Database: videosdb (RDS do serviço Videos)
-- Applied by: scripts/run_migrations.sh or manually via psql
-- Uso: quando o banco é destruído e recriado na AWS, apenas esta migration é necessária.

-- Tabela principal de vídeos
CREATE TABLE IF NOT EXISTS videos (
    id               SERIAL PRIMARY KEY,
    user_id          INTEGER NOT NULL,
    title            TEXT NOT NULL,
    description      TEXT NOT NULL DEFAULT '',
    status           TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    storage_key      TEXT,
    result_zip_path  TEXT,
    error_message    TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS videos_user_id_idx ON videos (user_id);
CREATE INDEX IF NOT EXISTS videos_id_idx ON videos (id);

COMMENT ON COLUMN videos.user_id IS 'ID do usuário dono do vídeo (X-User-Id do API Gateway)';
COMMENT ON COLUMN videos.status IS 'pending | processing | completed | failed';
COMMENT ON COLUMN videos.storage_key IS 'Chave do objeto no S3 (vídeo original)';
COMMENT ON COLUMN videos.result_zip_path IS 'Caminho ou chave do ZIP de frames gerado';
