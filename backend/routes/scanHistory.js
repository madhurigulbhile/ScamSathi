
const express = require("express");
const mongoose = require("mongoose");
const ScanHistory = require("../models/ScanHistory");
const authMiddleware = require("../middleware/authMiddleware");

const router = express.Router();

// Save a scan for the logged-in user
router.post("/scan-history", authMiddleware, async (req, res) => {
  try {
    const { scanType, inputText, result } = req.body;

    if (!["message", "link"].includes(scanType)) {
      return res.status(400).json({
        message: "scanType must be 'message' or 'link'.",
      });
    }

    if (typeof inputText !== "string" || !inputText.trim()) {
      return res.status(400).json({
        message: "Scanned text or URL is required.",
      });
    }

    if (result === undefined || result === null) {
      return res.status(400).json({
        message: "Scan result is required.",
      });
    }

    const scan = await ScanHistory.create({
      userId: req.user.id,
      scanType,
      inputText: inputText.trim(),
      result,
    });

    return res.status(201).json({
      message: "Scan saved successfully.",
      scan,
    });
  } catch (error) {
    console.error("Saving scan failed:", error.message);
    return res.status(500).json({
      message: "Could not save scan history.",
    });
  }
});

// Get only the logged-in user's scans
router.get("/scan-history", authMiddleware, async (req, res) => {
  try {
    const scans = await ScanHistory.find({
      userId: req.user.id,
    }).sort({ createdAt: -1 });

    return res.json({ scans });
  } catch (error) {
    console.error("Loading scan history failed:", error.message);
    return res.status(500).json({
      message: "Could not load scan history.",
    });
  }
});

// Delete a scan only if it belongs to the logged-in user
router.delete("/scan-history/:id", authMiddleware, async (req, res) => {
  try {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(400).json({
        message: "Invalid scan ID.",
      });
    }

    const deletedScan = await ScanHistory.findOneAndDelete({
      _id: req.params.id,
      userId: req.user.id,
    });

    if (!deletedScan) {
      return res.status(404).json({
        message: "Scan not found.",
      });
    }

    return res.json({
      message: "Scan deleted successfully.",
    });
  } catch (error) {
    console.error("Deleting scan failed:", error.message);
    return res.status(500).json({
      message: "Could not delete scan.",
    });
  }
});

module.exports = router;
