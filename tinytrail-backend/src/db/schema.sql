
-- 1. Single teacher account
CREATE TABLE IF NOT EXISTS teachers (
    id SMALLINT PRIMARY KEY CHECK (id = 1),
    login_id VARCHAR(100) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Available game templates
CREATE TABLE IF NOT EXISTS game_templates (
    id SERIAL PRIMARY KEY,
    template_key VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- 3. Games created by the teacher
CREATE TABLE IF NOT EXISTS games (
    id BIGSERIAL PRIMARY KEY,
    teacher_id SMALLINT NOT NULL REFERENCES teachers(id),
    template_id INTEGER NOT NULL REFERENCES game_templates(id),
    title VARCHAR(150) NOT NULL,
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'published')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Questions belonging to each game
CREATE TABLE IF NOT EXISTS questions (
    id BIGSERIAL PRIMARY KEY,
    game_id BIGINT NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    prompt TEXT NOT NULL,
    question_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    sort_order INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Uploaded images and audio metadata
CREATE TABLE IF NOT EXISTS media_assets (
    id BIGSERIAL PRIMARY KEY,
    uploaded_by SMALLINT NOT NULL REFERENCES teachers(id),
    original_name VARCHAR(255) NOT NULL,
    storage_key TEXT UNIQUE NOT NULL,
    media_type VARCHAR(20) NOT NULL
        CHECK (media_type IN ('image', 'audio')),
    mime_type VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_games_status
    ON games(status);

CREATE INDEX IF NOT EXISTS idx_games_updated_at
    ON games(updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_questions_game_order
    ON questions(game_id, sort_order);

-- Insert reusable game templates
INSERT INTO game_templates (template_key, name, description)
VALUES
    ('matching', 'Matching Game',
     'Match related items or pictures'),
    ('multiple_choice', 'Multiple Choice',
     'Choose the correct answer'),
    ('picture_question', 'Picture Question',
     'Answer a question about a picture'),
    ('voice_to_drawing', 'Listen and Draw',
     'Listen to a prompt and draw or select the answer'),
    ('picture_matching', 'Picture Matching',
     'Match pictures using built-in or uploaded images')
ON CONFLICT (template_key) DO NOTHING;
