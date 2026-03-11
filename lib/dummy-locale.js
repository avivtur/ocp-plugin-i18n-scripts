#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { loadConfig } = require('./load-config.js');

const config = loadConfig();
const pluginName = config.pluginName;

const messagesPath = path.join(process.cwd(), 'locales', 'en', `${pluginName}.json`);
const messages = require(messagesPath);

const TARGETS_FOR_DUMMY_LOCALE = ['es', 'fr'];
const wrappers = {
  es: (message) => `\u21d2 ${message} \u21d0`,
  fr: (message) => `@ ${message} @`,
};

function insertDummyLocaleAndSave(messages, destination, wrap) {
  const dummyMessages = {};
  Object.keys(messages).forEach((key) => {
    const message = messages[key] ?? key;
    dummyMessages[key] = wrap(message);
  });

  const serializedContent = JSON.stringify(dummyMessages, null, '  ') + '\n';
  const dirname = path.dirname(destination);
  if (!fs.existsSync(dirname)) {
    fs.mkdirSync(dirname, { recursive: true });
  }
  fs.writeFileSync(destination, serializedContent);
}

TARGETS_FOR_DUMMY_LOCALE.forEach((target) => {
  const destination = path.join('locales', target, `${pluginName}.json`);
  insertDummyLocaleAndSave(messages, destination, wrappers[target]);
  console.log(`[ocp-i18n] dummy locale for ${target} inserted to ${destination}`);
});
