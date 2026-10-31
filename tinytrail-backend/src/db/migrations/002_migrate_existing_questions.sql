
BEGIN;

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

SELECT setval(
    pg_get_serial_sequence('question_bank', 'id'),
    COALESCE((SELECT MAX(id) FROM question_bank), 1),
    EXISTS (SELECT 1 FROM question_bank)
);

COMMIT;
