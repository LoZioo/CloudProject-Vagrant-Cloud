import axios from "axios";

// HTTP server.
const HTTP_ADDRESS = "0.0.0.0";
const HTTP_PORT = 80;

// Cloud block.
interface CloudBlock_t {
	VA:					Array<number>,
	W:					Array<number>,

	timestamp:	string,
	hash:				string,
}

// App log.
import { format } from  "util";
import { stdout, stderr } from "process";

function log(message: unknown, tag = "Info", file: NodeJS.WriteStream = stdout, newline = false): void {
	file.write(format("%s[%s] %s\n", newline ? "\n" : "", tag, message));
}

// Envroiment variables.
import { env } from "process";
import assert from "assert";

try {
	assert("OPENSTACK_CONTAINER" in env);
}
catch(e){
	log("OPENSTACK_CONTAINER envroiment variable not set, exiting...", "Error", stderr);
	process.exit(1);
}

const OPENSTACK_CONTAINER = env.OPENSTACK_CONTAINER as string;

// Express server.
import express, { Request, Response } from "express";
import bodyParser from "body-parser";

const app = express();
app.use(bodyParser.json());		// Now Express can decode the application/json body inside req.body.

app.get("/", async (req: Request, res: Response) => {
	let ret: Array<string> = [];

	try {
		const data = (await axios.get(OPENSTACK_CONTAINER)).data as string;
		ret = data.split("\n").map(e => "/forecast/" + e);
	}
	catch(e){
		res.status(500).send(format("Error with the openstack container: %s.", e));
	}

	res.send(ret);
});

app.get("/forecast/:filename", async (req: Request, res: Response) => {
	try {
		const block = (await axios.get(OPENSTACK_CONTAINER + req.params.filename)).data as CloudBlock_t;
		const ret = {
			VA: block.VA.reduce((sum, val) => sum + val),
			W: block.W.reduce((sum, val) => sum + val),

			timestamp: block.timestamp,
			hash: block.hash
		};

		ret.VA /= block.VA.length;
		ret.W /= block.W.length;

		res.send(ret);
	}
	catch(e){
		res.status(500).send(format("Error with the openstack container: %s.", e));
	}
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
log("I'm the forecaster!");
