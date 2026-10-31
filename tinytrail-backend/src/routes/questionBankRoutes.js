
const express = require("express");
const pool = require("../config/db");
const teacherAuthMiddleware = require("../middleware/teacherAuthMiddleware");
const router = express.Router();

function validateQuestionData(questionData) {
  if (
    !questionData ||
    typeof questionData !== "object" ||
    Array.isArray(questionData)
  ) {
    return "question_data must be a JSON object";
  }

  if (
    questionData.type !== "matching" &&
    questionData.type !== "multiple_choice"
  ) {
    return "Question type must be matching or multiple_choice";
  }

  if (questionData.type === "matching") {
    if (
      !Array.isArray(questionData.pairs) ||
      questionData.pairs.length === 0
    ) {
      return "Matching questions must contain at least one pair";
    }

    for (const pair of questionData.pairs) {
      if (
        !pair ||
        typeof pair.left !== "string" ||
        !pair.left.trim() ||
        typeof pair.right !== "string" ||
        !pair.right.trim()
      ) {
        return "Each matching pair must have non-empty left and right values";
      }
    }

    return null;
  }

  if (
    !Array.isArray(questionData.options) ||
    questionData.options.length < 2 ||
    questionData.options.some(
      (option) => typeof option !== "string" || !option.trim()
    )
  ) {
    return "Multiple-choice questions must have at least two non-empty options";
  }

  if (
    typeof questionData.answer !== "string" ||
    !questionData.answer.trim() ||
    !questionData.options.includes(questionData.answer)
  ) {
    return "The correct answer must be one of the options";
  }

  return null;
}
// Browse reusable questions.
router.get("/", teacherAuthMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, prompt, question_data, created_at, updated_at
          FROM question_bank
        WHERE teacher_id = $1
        ORDER BY updated_at DESC, id DESC`,
         [req.teacher.id]
    );

    return res.json({
      success: true,
      count: result.rowCount,
      questions: result.rows,
    });
  } catch (error) {
    console.error("Question library error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve question library",
    });
  }
});

// Create a reusable question without attaching it to a game.


router.post("/",teacherAuthMiddleware,  async (req, res) => {
  const { prompt, question_data } = req.body;

   const validationError = validateQuestionData(question_data);

  if (validationError) {
    return res.status(400).json({
      success: false,
      message: validationError,
    });
  }

 

  const cleanPrompt = prompt.trim();
  if (typeof prompt !== "string" || !prompt.trim()) {
  return res.status(400).json({
    success: false,
    message: "Prompt is required",
  });
  }
  try {
    // Check for an existing prompt, ignoring case and outer spaces.
    const duplicateResult = await pool.query(
      `SELECT id, prompt
       FROM question_bank
       WHERE teacher_id = $2
         AND LOWER(TRIM(prompt)) = LOWER(TRIM($1))
       LIMIT 1`,
      [cleanPrompt, req.teacher.id]
    );

    if (duplicateResult.rowCount > 0) {
      return res.status(409).json({
        success: false,
        message: "A question with this prompt already exists",
        existing_question: duplicateResult.rows[0],
      });
    }

    const result = await pool.query(
      `INSERT INTO question_bank
         (teacher_id, prompt, question_data)
       VALUES ($1, $2, $3)
       RETURNING id, prompt, question_data, created_at, updated_at`,
      [req.teacher.id, cleanPrompt, JSON.stringify(question_data)]
    );

    return res.status(201).json({
      success: true,
      message: "Question added to library",
      question: result.rows[0],
    });
  } catch (error) {
    if (error.code === "23505") {
  return res.status(409).json({
    success: false,
    message: "A question with this prompt already exists",
  });
}
    console.error("Create library question error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to create library question",
    });
  }
});


// Reuse an existing library question in a draft game.
router.post("/games/:gameId/questions/reuse",teacherAuthMiddleware,  async (req, res) => {
  const gameId = Number(req.params.gameId);
  const questionId = Number(req.body.question_id);
  const requestedOrder = req.body.sort_order;

  if (!Number.isSafeInteger(gameId) || gameId <= 0) {
    return res.status(400).json({
      success: false,
      message: "Invalid game ID",
    });
  }

  if (!Number.isSafeInteger(questionId) || questionId <= 0) {
    return res.status(400).json({
      success: false,
      message: "question_id must be a positive integer",
    });
  }

  if (
    requestedOrder !== undefined &&
    (!Number.isSafeInteger(requestedOrder) || requestedOrder < 1)
  ) {
    return res.status(400).json({
      success: false,
      message: "sort_order must be a positive integer",
    });
  }

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const gameResult = await client.query(
      "SELECT id, status FROM games WHERE id = $1",
      [gameId]
    );

    if (gameResult.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({
        success: false,
        message: "Game not found",
      });
    }

    if (gameResult.rows[0].status !== "draft") {
      await client.query("ROLLBACK");
      return res.status(400).json({
        success: false,
        message: "Questions can only be added to draft games",
      });
    }

    const questionResult = await client.query(
      "SELECT id FROM question_bank WHERE id = $1",
      [questionId]
    );

    if (questionResult.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({
        success: false,
        message: "Library question not found",
      });
    }

    const existingLink = await client.query(
      `SELECT 1 FROM game_questions
       WHERE game_id = $1 AND question_id = $2`,
      [gameId, questionId]
    );

    if (existingLink.rowCount > 0) {
      await client.query("ROLLBACK");
      return res.status(409).json({
        success: false,
        message: "This question is already in the game",
      });
    }

    const orderResult = await client.query(
      `SELECT COALESCE(MAX(sort_order), 0) + 1 AS next_order
       FROM game_questions
       WHERE game_id = $1`,
      [gameId]
    );

    const finalOrder = requestedOrder ?? orderResult.rows[0].next_order;

    await client.query(
      `INSERT INTO game_questions (game_id, question_id, sort_order)
       VALUES ($1, $2, $3)`,
      [gameId, questionId, finalOrder]
    );

    const result = await client.query(
      `SELECT qb.id, qb.prompt, qb.question_data,
              gq.sort_order
       FROM game_questions gq
       JOIN question_bank qb ON qb.id = gq.question_id
       WHERE gq.game_id = $1 AND gq.question_id = $2`,
      [gameId, questionId]
    );

    await client.query("COMMIT");

    return res.status(201).json({
      success: true,
      message: "Existing question added to game",
      question: result.rows[0],
    });
  } catch (error) {
    await client.query("ROLLBACK");

    if (error.code === "23505") {
      return res.status(409).json({
        success: false,
        message: "That question order is already in use",
      });
    }

    console.error("Reuse question error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to reuse question",
    });
  } finally {
    client.release();
  }
});

module.exports = router;
