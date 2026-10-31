
const express = require("express");
const jwt = require("jsonwebtoken");
const pool = require("../config/db");
const teacherAuthMiddleware = require("../middleware/teacherAuthMiddleware");

const router = express.Router();

// POST /api/teacher-auth/login
router.post("/login", async (req, res) => {
  try {
    const { loginId, password } = req.body;

    if (
  typeof loginId !== "string" ||
  !loginId.trim() ||
  typeof password !== "string" ||
  !password
)  {
      return res.status(400).json({
        success: false,
        message: "Teacher ID and password are required",
      });
    }

    const result = await pool.query(
      `SELECT id, login_id, password_hash
       FROM teachers
       WHERE login_id = $1`,
      [loginId]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: "Invalid teacher ID or password",
      });
    }

    const teacher = result.rows[0];

    // Plain-text comparison for this local demo only.
    if (password !== teacher.password_hash) {
      return res.status(401).json({
        success: false,
        message: "Invalid teacher ID or password",
      });
    }

    if (!process.env.JWT_SECRET) {
      console.error("JWT_SECRET is missing from the environment");
      return res.status(500).json({
        success: false,
        message: "Authentication is not configured",
      });
    }

    const token = jwt.sign(
      {
        teacherId: teacher.id,
        loginId: teacher.login_id,
      },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    return res.status(200).json({
      success: true,
      message: "Teacher login successful",
      teacher: {
        id: teacher.id,
        loginId: teacher.login_id,
      },
      token,
    });
  } catch (error) {
    console.error("Teacher login failed:", error.message);

    return res.status(500).json({
      success: false,
      message: "Unable to log in",
    });
  }
});



// POST /api/teacher-auth/change-password
router.post("/change-password", teacherAuthMiddleware, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    // if (!currentPassword || !newPassword) {
    //   return res.status(400).json({
    //     success: false,
    //     message: "Current password and new password are required",
    //   });
    // }
    if (
  typeof currentPassword !== "string" ||
  !currentPassword ||
  typeof newPassword !== "string" ||
  !newPassword
) {
  return res.status(400).json({
    success: false,
    message: "Current password and new password are required",
  });
}

    if (newPassword.length < 8) {
      return res.status(400).json({
        success: false,
        message: "New password must be at least 8 characters",
      });
    }

    const result = await pool.query(
      `SELECT id, password_hash
       FROM teachers
       WHERE id = $1`,
      [req.teacher.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Teacher account not found",
      });
    }

    if (currentPassword !== result.rows[0].password_hash) {
      return res.status(401).json({
        success: false,
        message: "Current password is incorrect",
      });
    }

    await pool.query(
      `UPDATE teachers
       SET password_hash = $1
       WHERE id = $2`,
      [newPassword, req.teacher.id]
    );

    return res.status(200).json({
      success: true,
      message: "Password changed successfully. Please log in again.",
    });
  } catch (error) {
    console.error("Password change failed:", error.message);

    return res.status(500).json({
      success: false,
      message: "Unable to change password",
    });
  }
});


module.exports = router;
