
const express = require("express");
const pool = require("../config/db");

const router = express.Router();

// GET /api/templates
router.get("/", async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, template_key, name, description
       FROM game_templates
       WHERE is_active = TRUE
       ORDER BY id ASC`
    );

    res.status(200).json({
      success: true,
      count: result.rows.length,
      templates: result.rows,
    });
  } catch (error) {
    console.error("Failed to fetch templates:", error.message);

    res.status(500).json({
      success: false,
      message: "Unable to fetch game templates",
    });
  }
});

module.exports = router;
