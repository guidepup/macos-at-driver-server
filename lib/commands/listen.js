"use strict";

const fs = require("fs/promises");
const path = require("path");

const createVoiceServer = require("../create-voice-server");

const MACOS_SOCKET_HANDLE = "/tmp/at_driver_generic/driver.socket";

const log = (...args) => console.log(new Date().toISOString(), ...args);

const prepareSocketPath = async (handle) => {
  await fs.mkdir(path.dirname(handle), { recursive: true });
  await fs.unlink(handle).catch((error) => {
    if (!error || error.code !== "ENOENT") {
      throw error;
    }
  });

  return handle;
};

module.exports = {
  command: "listen",
  describe: "Listen for macOS speech events and print every received message",
  async handler() {
    const handle = await prepareSocketPath(MACOS_SOCKET_HANDLE);
    const voiceServer = await createVoiceServer(handle);

    log(`Listening on Unix socket ${handle}`);

    voiceServer.on("error", (error) => log(`error: ${error.message}`));
    voiceServer.on("message", (message) => {
      log(JSON.stringify(message));
    });
  },
};
