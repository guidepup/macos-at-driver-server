"use strict";

const installation = require("../installation");

module.exports = {
  command: "install",
  describe: "Register the macOS speech extension",
  async handler() {
    await installation.install();
  },
};
