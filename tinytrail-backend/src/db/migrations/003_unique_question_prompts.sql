
CREATE UNIQUE INDEX uq_question_bank_teacher_prompt
ON question_bank (teacher_id, LOWER(TRIM(prompt)));

