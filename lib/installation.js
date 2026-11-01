"use strict";

const { exec: _exec } = require("child_process");
const fs = require("fs/promises");
const { resolve } = require("path");
const { promisify } = require("util");

const debug = require("debug")("install");

const LSREGISTER_EXECUTABLE_PATH =
  "/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister";

const APPLICATION_NAME = "MacOSATDriverServer.app";

const EXTENSION_IDENTIFIER =
  "com.bocoup.MacOSATDriverServer.MacOSATDriverServerExtension";

const VOICE_IDENTIFIER =
  "com.bocoup.MacOSATDriverServer.MacOSATDriverServerExtension.MacOSATDriverServerExtension";

const SYSTEM_VOICE_IDENTIFIER = "com.apple.Fred";

const PLUGIN_TRIPLET_IDENTIFIER = "ausp atdg BOCU";

const exec = async (command, options) => {
  try {
    return await promisify(_exec)(command, options);
  } catch (error) {
    const cwd = options?.cwd || process.cwd();
    const cwdExists = !!(await fs.stat(cwd).catch(() => null));

    if (error.code === "ENOENT" && !cwdExists) {
      throw new Error(`Cannot access directory: ${cwd}`, { cause: error });
    }
    throw error;
  }
};

exports.install = async function () {
  const options = await getExecOptions();

  if (await isInstalled()) {
    return console.log("Already installed.");
  }

  await removeQuarantine(options);
  await registerExtensions(options);
  await enableExtension();
  await setSystemVoice(VOICE_IDENTIFIER);

  console.log("Installation completed.");
};

exports.uninstall = async function () {
  const options = await getExecOptions();

  if (!(await isInstalled())) {
    throw new Error("Not installed");
  }

  await setSystemVoice(SYSTEM_VOICE_IDENTIFIER);
  await unregisterExtensions(options);
};

const isInstalled = async function () {
  let stdout;

  try {
    ({ stdout } = await exec(`auval -v ${PLUGIN_TRIPLET_IDENTIFIER}`));
  } catch (error) {
    if (error.stdout && error.stdout.includes("didn't find the component")) {
      return false;
    }

    throw error;
  }

  return /MacOSATDriverServerExtension/.test(stdout);
};

const getExecOptions = async function () {
  return {
    cwd: resolve(__dirname, "../src/MacOSATDriverServer/Build/Debug"),
  };
};

async function removeQuarantine(options) {
  debug("Removing macOS quarantine");

  await exec(`xattr -r -d com.apple.quarantine ${APPLICATION_NAME}`, options);
}

async function registerExtensions(options) {
  debug("Registering trusted macOS extension");

  await exec(
    `${LSREGISTER_EXECUTABLE_PATH} -f -R -trusted ${APPLICATION_NAME}`,
    options,
  );
}

async function unregisterExtensions(options) {
  debug("Unregistering trusted macOS extension");

  await exec(`${LSREGISTER_EXECUTABLE_PATH} -u ${APPLICATION_NAME}`, options);
}

async function enableExtension() {
  debug("Enabling macOS extension");

  await exec(`pluginkit -e use -i ${EXTENSION_IDENTIFIER}`);
}

async function setSystemVoice(newValue) {
  debug(`Setting macOS system voice to "${newValue}"`);

  let stdout;

  try {
    ({ stdout } = await exec(
      "defaults read com.apple.Accessibility SpeechVoiceIdentifierForLanguage",
    ));
  } catch (error) {
    if (!error || !error.stderr.includes("does not exist")) {
      throw error;
    }
  }

  const currentValue = stdout
    ? stdout.replace(/[\s]/g, "").match(/2={en="([^"]+)";};/)
    : null;

  if (currentValue && currentValue[1] === newValue) {
    return;
  }

  await exec(
    `defaults write com.apple.Accessibility SpeechVoiceIdentifierForLanguage '{2 = {en = "${newValue}";};}'`,
  );
}
