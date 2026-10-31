
require("dotenv").config();

const app = require("./app");
const pool = require("./config/db");

const PORT = Number(process.env.PORT) || 5000;

async function startServer() {
  try {
    // Confirm that PostgreSQL is reachable before starting.
    await pool.query("SELECT 1");

    app.listen(PORT, () => {
      console.log(`TinyTrail server running at http://localhost:${PORT}`);
      console.log("PostgreSQL connection successful");
    });
  } catch (error) {
    console.error("Failed to start TinyTrail:", error.message);
    await pool.end();
    process.exitCode = 1;
  }
}

startServer();
