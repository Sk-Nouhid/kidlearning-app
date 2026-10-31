
const express = require("express");
const pool = require("../config/db");
const teacherAuthMiddleware = require("../middleware/teacherAuthMiddleware");
const router = express.Router();

// POST /api/games
// Create a new game as a draft
router.post("/", teacherAuthMiddleware, async (req, res) => {
  const { title, description, template_id } = req.body;

  // Validate required fields
  if (
    typeof title !== "string" ||
    !title.trim() ||
    title.trim().length > 150 ||
    !Number.isInteger(template_id) ||
    template_id <= 0 ||
    (description != null && typeof description !== "string")
  ) {
    return res.status(400).json({
      success: false,
      message:
        "Provide a valid title (max 150 characters) and a positive integer template_id. Description must be text.",
    });
  }

  if (description && description.length > 5000) {
    return res.status(400).json({
      success: false,
      message: "Description must be 5000 characters or fewer.",
    });
  }

  try {
    // Check that the selected template exists and is active
    const templateResult = await pool.query(
      `SELECT id
       FROM game_templates
       WHERE id = $1 AND is_active = TRUE`,
      [template_id]
    );

    if (templateResult.rowCount === 0) {
      return res.status(400).json({
        success: false,
        message: "The selected game template does not exist or is inactive.",
      });
    }

    // Temporary teacher ID: the single teacher account uses ID 1
    // Teacher authentication will be added before production use.
    const teacherId = req.teacher.id;

    const result = await pool.query(
      `INSERT INTO games
         (teacher_id, template_id, title, description, status)
       VALUES ($1, $2, $3, $4, 'draft')
       RETURNING id, template_id, title, description, status,
                 created_at, updated_at`,
      [
        teacherId,
        template_id,
        title.trim(),
        description?.trim() || null,
      ]
    );

    return res.status(201).json({
      success: true,
      message: "Game draft created successfully",
      game: result.rows[0],
    });
  }  catch (error) {
  console.error("Failed to create game:", error);

  return res.status(500).json({
    success: false,
    message: "Unable to create game",
  });
}
});

 // GET /api/games
router.get("/", teacherAuthMiddleware, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
         g.id,
         g.title,
         g.description,
         g.status,
         g.template_id,
         t.name AS template_name,
         g.created_at,
         g.updated_at
       FROM games g
       INNER JOIN game_templates t ON t.id = g.template_id
       ORDER BY g.updated_at DESC, g.id DESC`
    );

    return res.status(200).json({
      success: true,
      count: result.rows.length,
      games: result.rows,
    });
  } catch (error) {
    console.error("Failed to fetch games:", error.message);

    return res.status(500).json({
      success: false,
      message: "Unable to fetch games",
    });
  }
});


 // GET /api/games/published
// Return published games for the child-facing Flutter app
router.get("/published", async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
         g.id,
         g.title,
         g.description,
         g.status,
         g.template_id,
         t.name AS template_name,
         g.created_at,
         g.updated_at
       FROM games g
       INNER JOIN game_templates t ON t.id = g.template_id
       WHERE g.status = 'published'
       ORDER BY g.updated_at DESC, g.id DESC`
    );

    return res.status(200).json({
      success: true,
      count: result.rows.length,
      games: result.rows,
    });
  } catch (error) {
    console.error("Failed to fetch published games:", error.message);

    return res.status(500).json({
      success: false,
      message: "Unable to fetch published games",
    });
  }
});

 // PUT /api/games/:gameId
// Update the title and description of a draft game
router.put("/:gameId", teacherAuthMiddleware, async (req, res) => {
  const gameId = Number(req.params.gameId);
  const { title, description } = req.body;

  if (!Number.isSafeInteger(gameId) || gameId <= 0) {
    return res.status(400).json({
      success: false,
      message: "Invalid game ID",
    });
  }

  if (
    typeof title !== "string" ||
    !title.trim() ||
    title.trim().length > 150 ||
    (description != null && typeof description !== "string") ||
    (typeof description === "string" && description.length > 5000)
  ) {
    return res.status(400).json({
      success: false,
      message:
        "Provide a valid title (max 150 characters) and a description of 5000 characters or fewer.",
    });
  }

  try {
    const result = await pool.query(
      `UPDATE games
       SET title = $1,
           description = $2,
           updated_at = NOW()
       WHERE id = $3
         AND status = 'draft'
       RETURNING id, template_id, title, description,
                 status, created_at, updated_at`,
      [title.trim(), description?.trim() || null, gameId]
    );

    if (result.rowCount === 0) {
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

      return res.status(409).json({
        success: false,
        message: "Only draft games can be edited",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Game updated successfully",
      game: result.rows[0],
    });
  } catch (error) {
    console.error("Failed to update game:", error.message);

    return res.status(500).json({
      success: false,
      message: "Unable to update game",
    });
  }
});


 // PATCH /api/games/:gameId/publish

router.patch("/:gameId/publish", teacherAuthMiddleware, async (req, res) => {
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

    if (gameResult.rows[0].status === "published") {
      return res.status(409).json({
        success: false,
        message: "Game is already published",
      });
    }

    // Count questions linked to this game.
    const questionResult = await pool.query(
      `SELECT COUNT(*)::int AS count
       FROM game_questions
       WHERE game_id = $1`,
      [gameId]
    );

    const questionCount = questionResult.rows[0].count;

    // Require at least 5 questions before publishing.
    if (questionCount < 5) {
      return res.status(400).json({
        success: false,
        message: "Add at least 5 questions before publishing",
        current_questions: questionCount,
        required_questions: 5,
      });
    }

    const result = await pool.query(
      `UPDATE games
       SET status = 'published', updated_at = NOW()
       WHERE id = $1 AND status = 'draft'
       RETURNING id, title, description, status, updated_at`,
      [gameId]
    );

    return res.status(200).json({
      success: true,
      message: "Game published successfully",
      game: result.rows[0],
    });
  } catch (error) {
    console.error("Failed to publish game:", error.message);

    return res.status(500).json({
      success: false,
      message: "Unable to publish game",
    });
  }
});



 // DELETE /api/games/:gameId
// Delete a draft game without deleting reusable questions
router.delete("/:gameId", teacherAuthMiddleware, async (req, res) => {
  const gameId = Number(req.params.gameId);

  if (!Number.isSafeInteger(gameId) || gameId <= 0) {
    return res.status(400).json({
      success: false,
      message: "Invalid game ID",
    });
  }

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const gameResult = await client.query(
      `SELECT id, status
       FROM games
       WHERE id = $1
       FOR UPDATE`,
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

      return res.status(409).json({
        success: false,
        message: "Only draft games can be deleted",
      });
    }

    await client.query(
      "DELETE FROM game_questions WHERE game_id = $1",
      [gameId]
    );

    await client.query(
      "DELETE FROM games WHERE id = $1",
      [gameId]
    );

    await client.query("COMMIT");

    return res.status(200).json({
      success: true,
      message: "Draft game deleted successfully",
      game_id: gameId,
    });
  } catch (error) {
    await client.query("ROLLBACK");

    console.error("Failed to delete game:", error.message);

    return res.status(500).json({
      success: false,
      message: "Unable to delete game",
    });
  } finally {
    client.release();
  }
});

module.exports = router;
