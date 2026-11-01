"use strict";

const installation = require("../installation");

module.exports = {
  command: "uninstall",
  describe: "Unregister the macOS speech extension",
  async handler() {
    await installation.uninstall();
  },
};
