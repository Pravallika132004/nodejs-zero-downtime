const express = require("express");
const os = require("os");

const app = express();

const PORT = process.env.PORT || 3000;
const VERSION = process.env.VERSION || "v2";

app.get("/", (req, res) => {
    res.json({
        message: "Node.js Zero-Downtime Application",
        version: VERSION,
        instance: os.hostname()
    });
});

app.get("/health", (req, res) => {
    res.status(200).json({
        status: "healthy",
        version: VERSION,
        instance: os.hostname()
    });
});

if (require.main === module) {
    const server = app.listen(PORT, "0.0.0.0", () => {
        console.log(`Server ${VERSION} running on port ${PORT}`);
    });

    const shutdown = (signal) => {
        console.log(`${signal} received. Starting graceful shutdown...`);

        server.close(() => {
            console.log("All connections closed. Server stopped.");
            process.exit(0);
        });

        setTimeout(() => {
            console.log("Forcing shutdown...");
            process.exit(1);
        }, 10000).unref();
    };

    process.on("SIGTERM", () => shutdown("SIGTERM"));
    process.on("SIGINT", () => shutdown("SIGINT"));
}

module.exports = app;