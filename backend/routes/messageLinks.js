
const express = require("express");
const router = express.Router();

const URL_CHECKER_URL = "http://127.0.0.1:3000/check";

function extractUrls(message) {
  const matches =
    message.match(/(?:https?:\/\/|www\.)[^\s<>"']+/gi) || [];

  const cleaned = matches
    .map((url) => url.replace(/[),.!?;:}\]]+$/g, ""))
    .map((url) => {
      if (/^www\./i.test(url)) {
        return `https://${url}`;
      }
      return url;
    });

  return [...new Set(cleaned)];
}

router.post("/check-message-links", async (req, res) => {
  try {
    const message = req.body.message;

    if (typeof message !== "string" || !message.trim()) {
      return res.status(400).json({
        error: "Please provide a message to scan.",
      });
    }

    if (message.length > 10000) {
      return res.status(400).json({
        error: "Message must be 10,000 characters or fewer.",
      });
    }

    const urls = extractUrls(message);

    if (urls.length === 0) {
      return res.json({
        totalLinks: 0,
        results: [],
        message: "No recognizable links were found in this message.",
      });
    }

    // Limit requests to avoid sending too many lookups at once.
    const limitedUrls = urls.slice(0, 10);

    const results = await Promise.all(
      limitedUrls.map(async (url) => {
        try {
          const response = await fetch(URL_CHECKER_URL, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ url }),
            signal: AbortSignal.timeout(20000),
          });

          const data = await response.json();

          if (!response.ok) {
            return {
              url,
              status: "error",
              message: data.error || "URL lookup failed.",
            };
          }

          return {
            url,
            status: data.status || "unknown",
            message: data.message || "No additional details available.",
            urlStatus: data.urlStatus || null,
            reference: data.reference || null,
          };
        } catch (error) {
          console.error("Link lookup failed:", error.message);

          return {
            url,
            status: "error",
            message: "Could not complete this link lookup.",
          };
        }
      })
    );

    return res.json({
      totalLinks: urls.length,
      checkedLinks: results.length,
      skippedLinks: Math.max(0, urls.length - results.length),
      results,
      message:
        urls.length > results.length
          ? "Only the first 10 links were checked."
          : "Link checks completed.",
    });
  } catch (error) {
    console.error("Message link scan failed:", error.message);

    return res.status(500).json({
      error: "Could not scan links in this message.",
    });
  }
});

module.exports = router;
