import { createHash } from "crypto";

// HTTP server.
const HTTP_ADDRESS = "0.0.0.0";
const HTTP_PORT = 80;

// App log.
import { format } from  "util";
import { stdout } from "process";

function log(message: unknown, tag = "Info", file: NodeJS.WriteStream = stdout, newline = false): void {
	file.write(format("%s[%s] %s\n", newline ? "\n" : "", tag, message));
}

// Express server.
import express, { Request, Response } from "express";
import bodyParser from "body-parser";

const app = express();
app.use(bodyParser.json());		// Now Express can decode the application/json body inside req.body.

app.get("/", async (req: Request, res: Response) => {
	// Available endpoints.
	const endpoints = {
		service: "benchmarker",
		endpoints: [
			{
				endpoint:			"/blockchain/bench/get/user_id",
				method:				"get",
				body:					null,
				bodyType:			null,
				returns:			"Number",
				description:	"Get the user's dependability rating (1 to 10)."
			}
		]
	};

	// Send response.
	res.contentType("application/json");
	res.send(JSON.stringify(endpoints));
});

app.get("/blockchain/bench/get/:id", async (req: Request, res: Response) => {
	const hash = createHash("sha256").update(req.params.id).digest("hex");
	const n = parseInt(hash, 16);
	const r = (n % 10) + 1;

	res.send(r.toString());
});

const server = app.listen(HTTP_PORT, HTTP_ADDRESS, () => {
	log(format("Server is running at http://%s:%d.", HTTP_ADDRESS, HTTP_PORT));
});

// Graceful shutdown.
process.once("SIGINT", gracefulShutdown);
process.once("SIGTERM", gracefulShutdown);

function gracefulShutdown(): void {
	log("SIGINT detected, exiting...", "Info", stdout, true);

	server.close();
	process.exit(0);
}

// Main.
log("I'm the benchmarker!");
