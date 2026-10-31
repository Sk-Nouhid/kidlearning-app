
const express = require("express");
const pool = require("../config/db");
const teacherAuthMiddleware = require("../middleware/teacherAuthMiddleware");

const router = express.Router();

function validateQuestionData(prompt, questionData) {
  if (typeof prompt !== "string" || !prompt.trim()) {
    return "Prompt is required.";
  }

  if (
    !questionData ||
    typeof questionData !== "object" ||
    Array.isArray(questionData)
  ) {
    return "Question data must be a JSON object.";
  }
  if (
    questionData.type !== "matching" &&
    questionData.type !== "multiple_choice"
  ) {
    return "Question type must be matching or multiple_choice.";
  }
  

  if (questionData.type === "matching") {
    if (
      !Array.isArray(questionData.pairs) ||
      questionData.pairs.length === 0
    ) {
      return "Matching questions must contain at least one pair.";
    }

    for (const pair of questionData.pairs) {
      if (
        !pair ||
        typeof pair.left !== "string" ||
        !pair.left.trim() ||
        typeof pair.right !== "string" ||
        !pair.right.trim()
      ) {
        return "Each matching pair must have non-empty left and right values.";
      }
    }
  }

  if (questionData.type === "multiple_choice") {
    if (
      !Array.isArray(questionData.options) ||
      questionData.options.length < 2
    ) {
      return "Multiple-choice questions must have at least two options.";
    }

    if (
      typeof questionData.answer !== "string" ||
      !questionData.answer.trim()
    ) {
      return "Multiple-choice questions must have a correct answer.";
    }

    if (!questionData.options.includes(questionData.answer)) {
      return "The correct answer must be one of the options.";
    }

    if (
      questionData.options.some(
        (option) => typeof option !== "string" || !option.trim()
      )
    ) {
      return "All options must be non-empty strings.";
    }
  }

  return null;
}
// Create a new library question and attach it to a draft game.

router.post("/:gameId/questions", teacherAuthMiddleware, async (req, res) => {
  const gameId = Number(req.params.gameId);
  const { question_id, prompt, question_data, sort_order } = req.body;

  if (!Number.isSafeInteger(gameId) || gameId <= 0) {
    return res.status(400).json({
      success: false,
      message: "Invalid game ID",
    });
  }

  const reuseExisting = question_id !== undefined;

  // Validate the existing question ID when reusing a library question.
  if (
    reuseExisting &&
    (!Number.isSafeInteger(question_id) || question_id <= 0)
  ) {
    return res.status(400).json({
      success: false,
      message: "question_id must be a positive integer",
    });
  }

  // Validate prompt and question data when creating a new question.
  if (
    !reuseExisting &&
    (typeof prompt !== "string" ||
      !prompt.trim() ||
      prompt.trim().length > 2000)
  ) {
    return res.status(400).json({
      success: false,
      message: "Prompt is required and must not exceed 2000 characters",
    });
  }

  if (
    !reuseExisting &&
    (!question_data ||
      typeof question_data !== "object" ||
      Array.isArray(question_data))
  ) {
    return res.status(400).json({
      success: false,
      message: "question_data must be a JSON object",
    });
  }
    if (!reuseExisting) {
    const validationError = validateQuestionData(
      prompt,
      question_data
    );

    if (validationError) {
      return res.status(400).json({
        success: false,
        message: validationError,
      });
    }
  }
  if (
    sort_order !== undefined &&
    (!Number.isSafeInteger(sort_order) || sort_order < 1)
  ) {
    return res.status(400).json({
      success: false,
      message: "sort_order must be a positive integer",
    });
  }

  const client = await pool.connect();
  let transactionStarted = false;

  try {
    await client.query("BEGIN");
    transactionStarted = true;

    const gameResult = await client.query(
      "SELECT id, status FROM games WHERE id = $1",
      [gameId]
    );

    if (gameResult.rowCount === 0) {
      await client.query("ROLLBACK");
      transactionStarted = false;

      return res.status(404).json({
        success: false,
        message: "Game not found",
      });
    }

    if (gameResult.rows[0].status !== "draft") {
      await client.query("ROLLBACK");
      transactionStarted = false;

      return res.status(400).json({
        success: false,
        message: "Questions can only be added to draft games",
      });
    }

    const orderResult = await client.query(
      `SELECT COALESCE(MAX(sort_order), 0) + 1 AS next_order
       FROM game_questions
       WHERE game_id = $1`,
      [gameId]
    );

    const finalOrder = sort_order ?? Number(orderResult.rows[0].next_order);

    let question;

    if (reuseExisting) {
      // Reuse the existing library question without copying it.
      const existingResult = await client.query(
        `SELECT id, prompt, question_data, created_at, updated_at
         FROM question_bank
         WHERE id = $1`,
        [question_id]
      );

      if (existingResult.rowCount === 0) {
        await client.query("ROLLBACK");
        transactionStarted = false;

        return res.status(404).json({
          success: false,
          message: "Library question not found",
        });
      }

      question = existingResult.rows[0];
    } else {
      // Create a new library question.
      const questionResult = await client.query(
        `INSERT INTO question_bank
           (teacher_id, prompt, question_data)
         VALUES ($1, $2, $3::jsonb)
         RETURNING id, prompt, question_data, created_at, updated_at`,
        [req.teacher.id, prompt.trim(), JSON.stringify(question_data)]
      );

      question = questionResult.rows[0];
    }

    // Attach either the reused question or the newly created question.
    await client.query(
      `INSERT INTO game_questions (game_id, question_id, sort_order)
       VALUES ($1, $2, $3)`,
      [gameId, question.id, finalOrder]
    );

    await client.query("COMMIT");
    transactionStarted = false;

    return res.status(201).json({
      success: true,
      message: reuseExisting
        ? "Library question reused and added to game"
        : "Question created and added to game",
      question: {
        ...question,
        sort_order: finalOrder,
      },
    });
  } catch (error) {
    if (transactionStarted) {
      try {
        await client.query("ROLLBACK");
      } catch (rollbackError) {
        console.error("Rollback error:", rollbackError.message);
      }
    }
        
    if (error.code === "23505") {
      return res.status(409).json({
        success: false,
        message: "This question or question order is already in use",
      });
    }

    console.error("Create question error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to add question to game",
    });
  } finally {
    client.release();
  }
});


// Get questions attached to a game.

 // Get questions attached to a game.
router.get("/:gameId/questions", async (req, res) => {
  const gameId = Number(req.params.gameId);

  if (!Number.isSafeInteger(gameId) || gameId <= 0) {
    return res.status(400).json({
      success: false,
      message: "Invalid game ID",
    });
  }

  try {
    const gameResult = await pool.query(
      "SELECT id, status FROM games WHERE id = $1",
      [gameId]
    );

    if (gameResult.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: "Game not found",
      });
    }

    // Draft questions require teacher authentication.
    if (gameResult.rows[0].status !== "published") {
      const authHeader = req.headers.authorization;
      const token = authHeader?.startsWith("Bearer ")
        ? authHeader.slice(7)
        : null;

      if (!token) {
        return res.status(401).json({
          success: false,
          message: "Teacher authentication is required to view draft questions",
        });
      }

      try {
        const jwt = require("jsonwebtoken");
        jwt.verify(token, process.env.JWT_SECRET);
      } catch (error) {
        return res.status(401).json({
          success: false,
          message: "Invalid or expired authentication token",
        });
      }
    }

    const result = await pool.query(
      `SELECT
         qb.id,
         qb.prompt,
         qb.question_data,
         gq.sort_order,
         qb.created_at,
         qb.updated_at
       FROM game_questions gq
       JOIN question_bank qb ON qb.id = gq.question_id
       WHERE gq.game_id = $1
       ORDER BY gq.sort_order ASC, qb.id ASC`,
      [gameId]
    );

    return res.json({
      success: true,
      count: result.rowCount,
      questions: result.rows,
    });
  } catch (error) {
    console.error("Get questions error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to retrieve questions",
    });
  }
});


// Edit a question attached to a draft game.
router.put("/:gameId/questions/:questionId",teacherAuthMiddleware, async (req, res) => {
  const gameId = Number(req.params.gameId);
  const questionId = Number(req.params.questionId);
  const { prompt, question_data, sort_order } = req.body;

  // Validate IDs
  if (
    !Number.isSafeInteger(gameId) ||
    gameId <= 0 ||
    !Number.isSafeInteger(questionId) ||
    questionId <= 0
  ) {
    return res.status(400).json({
      success: false,
      message: "Invalid game ID or question ID",
    });
  }

  // Validate prompt
  if (
    prompt !== undefined &&
    (typeof prompt !== "string" ||
      !prompt.trim() ||
      prompt.trim().length > 2000)
  ) {
    return res.status(400).json({
      success: false,
      message: "Prompt must be non-empty and at most 2000 characters",
    });
  }

  // Validate question data
  if (
    question_data !== undefined &&
    (question_data === null ||
      typeof question_data !== "object" ||
      Array.isArray(question_data))
  ) {
    return res.status(400).json({
      success: false,
      message: "question_data must be a JSON object",
    });
  }

  // Validate order
  if (
    sort_order !== undefined &&
    (!Number.isSafeInteger(sort_order) || sort_order < 1)
  ) {
    return res.status(400).json({
      success: false,
      message: "sort_order must be a positive integer",
    });
  }
    // Validate the final question content when either content field is updated.
  if (prompt !== undefined || question_data !== undefined) {
    const validationError = validateQuestionData(
      prompt !== undefined ? prompt : "Existing prompt",
      question_data !== undefined
        ? question_data
        : { type: "unsupported" }
    );

    if (validationError && question_data !== undefined) {
      return res.status(400).json({
        success: false,
        message: validationError,
      });
    }
  }

  if (
    prompt === undefined &&
    question_data === undefined &&
    sort_order === undefined
  ) {
    return res.status(400).json({
      success: false,
      message: "Provide at least one field to update",
    });
  }

  const client = await pool.connect();
  let transactionStarted = false;

  try {
    await client.query("BEGIN");
    transactionStarted = true;

    // Confirm the game exists and is still a draft.
    const gameResult = await client.query(
      "SELECT status FROM games WHERE id = $1",
      [gameId]
    );

    if (gameResult.rowCount === 0) {
      await client.query("ROLLBACK");
      transactionStarted = false;

      return res.status(404).json({
        success: false,
        message: "Game not found",
      });
    }

    if (gameResult.rows[0].status !== "draft") {
      await client.query("ROLLBACK");
      transactionStarted = false;

      return res.status(400).json({
        success: false,
        message: "Only draft games can be edited",
      });
    }

    // Get the question attached to this specific game.
    const linkResult = await client.query(
      `SELECT
         qb.id,
         qb.teacher_id,
         qb.prompt,
         qb.question_data,
         gq.sort_order
       FROM game_questions gq
       JOIN question_bank qb ON qb.id = gq.question_id
       WHERE gq.game_id = $1
         AND gq.question_id = $2
       FOR UPDATE OF gq`,
      [gameId, questionId]
    );

    if (linkResult.rowCount === 0) {
      await client.query("ROLLBACK");
      transactionStarted = false;

      return res.status(404).json({
        success: false,
        message: "Question is not attached to this game",
      });
    }

    const existingQuestion = linkResult.rows[0];
       
    const finalPrompt =
      prompt !== undefined ? prompt.trim() : existingQuestion.prompt;

    const finalQuestionData =
      question_data !== undefined
        ? question_data
        : existingQuestion.question_data;

    const validationError = validateQuestionData(
      finalPrompt,
      finalQuestionData
    );

    if (validationError) {
      await client.query("ROLLBACK");
      transactionStarted = false;

      return res.status(400).json({
        success: false,
        message: validationError,
      });
    }

    const contentChanged =
      prompt !== undefined || question_data !== undefined;

    let effectiveQuestionId = questionId;

    // Copy-on-edit: never modify the original reusable question.
    if (contentChanged) {
      const newPrompt =
        prompt !== undefined ? prompt.trim() : existingQuestion.prompt;

      const newQuestionData =
        question_data !== undefined
          ? question_data
          : existingQuestion.question_data;

      const copiedQuestion = await client.query(
        `INSERT INTO question_bank
           (teacher_id, prompt, question_data)
         VALUES ($1, $2, $3::jsonb)
         RETURNING id`,
        [
          existingQuestion.teacher_id,
          newPrompt,
          JSON.stringify(newQuestionData),
        ]
      );

      effectiveQuestionId = copiedQuestion.rows[0].id;

      // Change the link for this game only.
      await client.query(
        `UPDATE game_questions
         SET question_id = $1
         WHERE game_id = $2 AND question_id = $3`,
        [effectiveQuestionId, gameId, questionId]
      );
    }

    // Update the order independently of the question content.
    if (sort_order !== undefined) {
      await client.query(
        `UPDATE game_questions
         SET sort_order = $1
         WHERE game_id = $2 AND question_id = $3`,
        [sort_order, gameId, effectiveQuestionId]
      );
    }

    const result = await client.query(
      `SELECT
         qb.id,
         qb.prompt,
         qb.question_data,
         gq.sort_order,
         qb.created_at,
         qb.updated_at
       FROM game_questions gq
       JOIN question_bank qb ON qb.id = gq.question_id
       WHERE gq.game_id = $1
         AND gq.question_id = $2`,
      [gameId, effectiveQuestionId]
    );

    await client.query("COMMIT");
    transactionStarted = false;

    return res.json({
      success: true,
      message: "Question updated successfully",
      question: result.rows[0],
    });
  } catch (error) {
    if (transactionStarted) {
      try {
        await client.query("ROLLBACK");
      } catch (rollbackError) {
        console.error("Rollback error:", rollbackError.message);
      }
    }

    
    if (error.code === "23505") {
      if (error.constraint === "uq_question_bank_teacher_prompt") {
        return res.status(409).json({
          success: false,
          message: "A question with this prompt already exists",
        });
      }

      return res.status(409).json({
        success: false,
        message: "That question order is already in use",
      });
    }


    console.error("Update question error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to update question",
    });
  } finally {
    client.release();
  }
});

// Remove a question from a draft game, but keep it in the library.
router.delete("/:gameId/questions/:questionId",teacherAuthMiddleware, async (req, res) => {
  const gameId = Number(req.params.gameId);
  const questionId = Number(req.params.questionId);

  if (
    !Number.isSafeInteger(gameId) ||
    gameId <= 0 ||
    !Number.isSafeInteger(questionId) ||
    questionId <= 0
  ) {
    return res.status(400).json({
      success: false,
      message: "Invalid game ID or question ID",
    });
  }

  try {
    const gameResult = await pool.query(
      "SELECT status FROM games WHERE id = $1",
      [gameId]
    );

    if (gameResult.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: "Game not found",
      });
    }

    if (gameResult.rows[0].status !== "draft") {
      return res.status(400).json({
        success: false,
        message: "Only draft games can be edited",
      });
    }

    const result = await pool.query(
      `DELETE FROM game_questions
       WHERE game_id = $1 AND question_id = $2
       RETURNING question_id`,
      [gameId, questionId]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: "Question is not attached to this game",
      });
    }

    return res.json({
      success: true,
      message: "Question removed from game; library question preserved",
      question_id: questionId,
    });
  } catch (error) {
    console.error("Delete question error:", error.message);

    return res.status(500).json({
      success: false,
      message: "Failed to remove question from game",
    });
  }
});

module.exports = router;
