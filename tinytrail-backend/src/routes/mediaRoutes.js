
const express = require("express");
const multer = require("multer");
const path = require("path");
const crypto = require("crypto");
const fs = require("fs");
const pool = require("../config/db");
const teacherAuthMiddleware = require("../middleware/teacherAuthMiddleware");

const router = express.Router();

const uploadDir = path.join(__dirname, "../../uploads");

fs.mkdirSync(uploadDir, { recursive: true });

const allowedMimeTypes = {
  "image/jpeg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp",
  "image/gif": ".gif",
};

const storage = multer.diskStorage({
  destination: (req, file, callback) => {
    callback(null, uploadDir);
  },
  filename: (req, file, callback) => {
    const extension = allowedMimeTypes[file.mimetype];

    if (!extension) {
      return callback(new Error("Only JPG, PNG, WEBP, and GIF images are allowed"));
    }

    callback(null, `${crypto.randomUUID()}${extension}`);
  },
});

const upload = multer({
  storage,
  limits: {
    fileSize: 5 * 1024 * 1024,
    files: 1,
  },
  fileFilter: (req, file, callback) => {
    if (!allowedMimeTypes[file.mimetype]) {
      return callback(
        new Error("Only JPG, PNG, WEBP, and GIF images are allowed")
      );
    }

    callback(null, true);
  },
});

// Upload one image.
// Form field name: image
router.post("/upload", teacherAuthMiddleware, (req, res) => {
  upload.single("image")(req, res, async (uploadError) => {
    if (uploadError) {
      const isSizeError = uploadError.code === "LIMIT_FILE_SIZE";

      return res.status(isSizeError ? 413 : 400).json({
        success: false,
        message: isSizeError
          ? "Image size must not exceed 5 MB"
          : uploadError.message,
      });
    }

    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: "Please select an image using the image field",
      });
    }

    try {
      const result = await pool.query(
        `INSERT INTO media_assets
          (uploaded_by, original_name, storage_key, media_type, mime_type)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id, original_name, storage_key, media_type, mime_type, created_at`,
         [
          req.teacher.id,
          path.basename(req.file.originalname).slice(0, 255),
          req.file.filename,
          "image",
          req.file.mimetype,
        ]
      );

      const asset = result.rows[0];

      return res.status(201).json({
        success: true,
        message: "Image uploaded successfully",
        asset: {
          ...asset,
          url: `/uploads/${encodeURIComponent(asset.storage_key)}`,
        },
      });
    } catch (error) {
      // Remove the file if saving its database record fails.
      await fs.promises.unlink(req.file.path).catch(() => {});

      console.error("Image upload failed:", error.message);

      return res.status(500).json({
        success: false,
        message: "Could not save image information",
      });
    }
  });
});

// Get all uploaded images
router.get("/",teacherAuthMiddleware, async (req, res) => {
  try {
   const result = await pool.query(
  `SELECT id, original_name, storage_key, media_type, mime_type, created_at
   FROM media_assets
   WHERE media_type = $1
     AND uploaded_by = $2
   ORDER BY created_at DESC`,
  ["image", req.teacher.id]
);

    const images = result.rows.map((asset) => ({
      ...asset,
      url: `/uploads/${encodeURIComponent(asset.storage_key)}`,
    }));

    res.status(200).json({
      success: true,
      count: images.length,
      images,
    });
  } catch (error) {
    console.error("Failed to fetch images:", error.message);

    res.status(500).json({
      success: false,
      message: "Could not retrieve uploaded images",
    });
  }
});

module.exports = router;
