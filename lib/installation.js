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

  await removeQuarantine(options);
  await registerExtensions(options);
  await enableExtension();
  await setSystemVoice(VOICE_IDENTIFIER);

  console.log("Installation completed.");
};

exports.uninstall = async function () {
  const options = await getExecOptions();
  await disableExtension();
  await unregisterExtensions(options);

  console.log("Uninstallation completed.");
};

const isInstalled = async function () {
  let stdout;

  try {
    ({ stdout } = await exec(
      "pluginkit -m -v -p com.apple.AudioUnit",
    ));
  } catch (error) {
    throw error;
  }

  return stdout.includes(EXTENSION_IDENTIFIER);
};

const getExecOptions = async function () {
  return {
    cwd: resolve(__dirname, "../src/MacOSATDriverServer/Build/Debug"),
  };
};

async function removeQuarantine(options) {
  debug("Removing macOS quarantine");

  await exec(`xattr -r -d com.apple.quarantine ${APPLICATION_NAME} 2>/dev/null || true`, options);
}

async function registerExtensions(options) {
  debug("Registering trusted macOS extension");

  await exec(
    `${LSREGISTER_EXECUTABLE_PATH} -f -R -trusted "./${APPLICATION_NAME}"`,
    options,
  );
}

async function unregisterExtensions(options) {
  debug("Unregistering trusted macOS extension");

  await exec(
    `${LSREGISTER_EXECUTABLE_PATH} -u "./${APPLICATION_NAME}"`,
    options,
  );
}

async function disableExtension() {
  debug("Disabling macOS extension");

  await exec(`pluginkit -e ignore -i ${EXTENSION_IDENTIFIER}`).catch(() => {});
}

async function enableExtension() {
  debug("Enabling macOS extension");

  await exec(`pluginkit -e use -i ${EXTENSION_IDENTIFIER}`);

  for (let attempt = 0; attempt < 50; attempt++) {
    if (await isInstalled()) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }

  throw new Error(
    `The MacOSATDriverServer speech extension did not register as "${EXTENSION_IDENTIFIER}"`,
  );
}

async function setSystemVoice(newValue) {
  debug(`Setting macOS system voice to "${newValue}"`);

  let stdout;

  try {
    ({ stdout } = await exec(
      "defaults read com.apple.Accessibility SpeechVoiceIdentifierForLanguage",
    ));
  } catch (error) {
    stdout = "";
  }

  if (stdout.includes(newValue)) {
    return;
  }

  await exec(
    `defaults write com.apple.Accessibility SpeechVoiceIdentifierForLanguage '{2 = {en = "${newValue}";};}'`,
  );
  const verification = await exec(
    "defaults read com.apple.Accessibility SpeechVoiceIdentifierForLanguage",
  );
  if (!verification.stdout.includes(newValue)) {
    throw new Error(
      "Unable to configure the macOS Accessibility speech voice identifier",
    );
  }
}
