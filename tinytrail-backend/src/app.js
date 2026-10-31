
const express = require("express");
const cors = require("cors");
const pool = require("./config/db");
const templateRoutes = require("./routes/templateRoutes");
const gameRoutes = require("./routes/gameRoutes");
const questionRoutes = require("./routes/questionRoutes");
const questionBankRoutes = require("./routes/questionBankRoutes");
const path = require("path");
const mediaRoutes = require("./routes/mediaRoutes");
const teacherAuthRoutes = require("./routes/teacherAuthRoutes");

const app = express();

app.use(cors());
app.use(express.json());

app.use(
  "/uploads",
  express.static(path.join(__dirname, "../uploads"))
);

// Root route
app.get("/", (req, res) => {
  res.send("TinyTrail backend is running!");
});

// Database health check
app.get("/api/health", async (req, res) => {
  try {
    const result = await pool.query("SELECT NOW() AS database_time");

    res.status(200).json({
      status: "healthy",
      message: "TinyTrail backend and database are connected",
      databaseTime: result.rows[0].database_time,
    });
  } catch (error) {
    console.error("Database health check failed:", error.message);

    res.status(503).json({
      status: "unhealthy",
      message: "Database connection failed",
    });
  }
});


app.use("/api/templates", templateRoutes);

app.use("/api/games", gameRoutes);

app.use("/api/games", questionRoutes);

app.use("/api/questions", questionBankRoutes);

app.use("/api/media", mediaRoutes);

app.use("/api/teacher-auth", teacherAuthRoutes);

module.exports = app;
