// HTTP server.
const HTTP_ADDRESS = "0.0.0.0";
const HTTP_PORT = 80;

// Blockchain port.
const BLOCKCHAIN_PORT = 5090;

// Cloud block.
interface CloudBlock_t {
	VA:					Array<number>,
	W:					Array<number>,

	timestamp:	string,
	hash:				string,
}

// Blockchain block.
interface BlockchainBlock_t {
	timestamp:	string,
	hash:				string,
}

/**
 * Check if obj is a CloudBlock_t object (check keys only, not values).
 * @param obj
 * @returns obj is CloudBlock_t
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function is_CloudBlock_t(obj: any): obj is CloudBlock_t {
	const testObj: CloudBlock_t = {
		VA: [],
		W: [],
		timestamp: "",
		hash: ""
	};

	const keys = Object.keys(testObj);
	return keys.every(key => key in obj);
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
	assert("BLOCKCHAIN_ADDRESS" in env);
}
catch(e){
	log("BLOCKCHAIN_ADDRESS envroiment variable not set, exiting...", "Error", stderr);
	process.exit(1);
}

const BLOCKCHAIN_ADDRESS = env.BLOCKCHAIN_ADDRESS as string;

try {
	assert("OPENSTACK_CONTAINER_NAME" in env);
}
catch(e){
	log("OPENSTACK_CONTAINER_NAME envroiment variable not set, exiting...", "Error", stderr);
	process.exit(1);
}

const OPENSTACK_CONTAINER_NAME = env.OPENSTACK_CONTAINER_NAME as string;

// Express server.
import express, { Request, Response } from "express";
import bodyParser from "body-parser";

const app = express();
app.use(bodyParser.json());		// Now Express can decode the application/json body inside req.body.

app.get("/", (req: Request, res: Response) => {
	// Available endpoints.
	const endpoints = {
		service: "exposer",
		endpoints: [
			{
				endpoint:			"/blockchain/block/get",
				method:				"get",
				body:					null,
				bodyType:			null,
				returns:			"Array<BlockchainBlock_t>",
				description:	"Get the blockchain content."
			},
			{
				endpoint:			"/container/block/get",
				method:				"get",
				body:					null,
				bodyType:			null,
				returns:			"Array<CloudBlock_t>",
				description:	"Get the openstack container content."
			},
		]
	};

	// Send response.
	res.contentType("application/json");
	res.send(JSON.stringify(endpoints));
});

app.get("/blockchain/block/get", async (req: Request, res: Response) => {
	// res.sendStatus(200);
	res.send(BLOCKCHAIN_ADDRESS);
});

app.get("/container/block/get", async (req: Request, res: Response) => {
	// res.sendStatus(200);
	res.send(OPENSTACK_CONTAINER_NAME);
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
log("I'm the exposer!");
