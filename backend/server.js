
require("dotenv").config();

const express = require("express");
const cors = require("cors");
const mongoose = require("mongoose");
mongoose
  .connect(process.env.MONGODB_URI)
  .then(() => console.log("MongoDB connected successfully!"))
 
 .catch((error) => {
    console.error("MongoDB connection failed:", error.message);
  });
const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

app.use("/api/auth", require("./routes/auth"));
app.use("/api", require("./routes/scanHistory"));
app.use("/api/scam-messages", require("./routes/scamMessage"));
app.use("/api/message-links", require("./routes/messageLinks"));

app.get("/", (req, res) => {
  res.json({ message: "ScamSathi backend is running!" });
});

app.post("/check", async (req, res) => {
  try {
    const input = String(req.body.url || "").trim();
    let parsed;

    try {
      parsed = new URL(input);
    } catch {
      return res.status(400).json({
        error: "Please enter a valid URL.",
      });
    }

    if (
      !["http:", "https:"].includes(parsed.protocol) ||
      !parsed.hostname.includes(".")
    ) {
      return res.status(400).json({
        error: "Only valid HTTP or HTTPS URLs are supported.",
      });
    }

    const apiKey = process.env.URLHAUS_AUTH_KEY;

    if (!apiKey) {
      return res.status(500).json({
        error: "URLhaus Auth-Key is not configured on the server.",
      });
    }

    const body = new URLSearchParams({ url: parsed.href });

    const response = await fetch(
      "https://urlhaus-api.abuse.ch/v1/url/",
      {
        method: "POST",
        headers: {
          "Auth-Key": apiKey,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body,
        signal: AbortSignal.timeout(15000),
      }
    );


    if (!response.ok) {
      const errorText = await response.text();

      console.error("URLhaus HTTP status:", response.status);
      console.error("URLhaus response:", errorText.slice(0, 500));

      return res.status(502).json({
        error: `URLhaus request failed (HTTP ${response.status}).`,
      });
    }

    const data = await response.json();

    if (data.query_status === "ok") {
      return res.json({
        status: "listed",
        message: "Warning: This URL is listed in URLhaus malware reports.",
        urlStatus: data.url_status,
        reference: data.urlhaus_reference,
      });
    }

    if (data.query_status === "no_results") {
      return res.json({
        status: "not_found",
        message:
          "This exact URL was not found in URLhaus. This does not guarantee that it is safe.",
      });
    }

    return res.status(502).json({
      error: "URLhaus could not complete the lookup.",
      details: data.query_status,
    });
  } catch (error) {
    console.error("URL check failed:", error.message);

    return res.status(500).json({
      error: "Could not complete the scan. Please try again.",
    });
  }
});

app.listen(PORT, () => {
  console.log(`ScamSathi backend running at http://localhost:${PORT}`);
});
