
BEGIN;

-- Store reusable questions independently of games.
CREATE TABLE IF NOT EXISTS question_bank (
    id BIGSERIAL PRIMARY KEY,
    teacher_id SMALLINT NOT NULL
        REFERENCES teachers(id),
    prompt TEXT NOT NULL
        CHECK (length(trim(prompt)) > 0),
    question_data JSONB NOT NULL
        CHECK (jsonb_typeof(question_data) = 'object'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Connect reusable questions to games.
CREATE TABLE IF NOT EXISTS game_questions (
    game_id BIGINT NOT NULL
        REFERENCES games(id) ON DELETE CASCADE,
    question_id BIGINT NOT NULL
        REFERENCES question_bank(id) ON DELETE RESTRICT,
    sort_order INTEGER NOT NULL DEFAULT 1
        CHECK (sort_order >= 1),
    PRIMARY KEY (game_id, question_id),
    UNIQUE (game_id, sort_order)
);

CREATE INDEX IF NOT EXISTS idx_game_questions_question_id
    ON game_questions(question_id);

COMMIT;

BEGIN;

-- Copy existing questions into the reusable question library.
INSERT INTO question_bank (
    id,
    teacher_id,
    prompt,
    question_data,
    created_at,
    updated_at
)
SELECT
    q.id,
    g.teacher_id,
    q.prompt,
    q.question_data,
    q.created_at,
    COALESCE(q.created_at, NOW())
FROM questions q
JOIN games g ON g.id = q.game_id
ON CONFLICT (id) DO NOTHING;

-- Connect each existing game to its migrated questions.
INSERT INTO game_questions (
    game_id,
    question_id,
    sort_order
)
SELECT
    q.game_id,
    q.id,
    q.sort_order
FROM questions q
ON CONFLICT DO NOTHING;

-- Keep future question IDs unique after migration.
SELECT setval(
    pg_get_serial_sequence('question_bank', 'id'),
    COALESCE((SELECT MAX(id) FROM question_bank), 1),
    EXISTS (SELECT 1 FROM question_bank)
);

COMMIT;
