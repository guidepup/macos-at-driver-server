"use strict";

const net = require("net");

const onConnection = (server, socket) => {
  let emitted = "";

  socket.on("data", (buffer) => {
    emitted += buffer.toString();
  });

  socket.on("end", () => {
    const match = emitted.match(/^(lifecycle|speech|internalError):(.*)$/s);

    const [name, data] = match
      ? [match[1], match[2]]
      : ["internalError", `unrecognized message: "${emitted}"`];

    server.emit("message", {
      type: name === "speech" ? "speech" : "lifecycle",
      name,
      data,
    });
  });
};

/**
 * Create a Unix socket server that emits events from the macOS speech extension.
 *
 * @param {string} handle - the address at which the server should listen for connections
 */
module.exports = function createVoiceServer(handle) {
  return new Promise((resolve, reject) => {
    const server = net.createServer();

    server.listen(
      {
        path: handle,
        writableAll: true,
      },
      () => resolve(server),
    );

    server.on("error", reject);
    server.on("connection", onConnection.bind(null, server));
  });
};
