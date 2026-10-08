process.env.VERSION = "v1";

const request = require("supertest");
const app = require("../src/server");

describe("Health Check API", () => {
    test("GET /health should return 200 and healthy status", async () => {
        const response = await request(app).get("/health");

        expect(response.statusCode).toBe(200);
        expect(response.body.status).toBe("healthy");
        expect(response.body.version).toBe("v1");
    });
});