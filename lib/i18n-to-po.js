#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const minimist = require('minimist');
const common = require('./common.js');

function save(target) {
  return (result) => {
    fs.writeFileSync(target, result);
  };
}

function removeValues(i18nFile, filePath) {
  const file = require(i18nFile);

  const updatedFile = {};

  const keys = Object.keys(file);

  for (let i = 0; i < keys.length; i++) {
    updatedFile[keys[i]] = '';
  }

  const tmpFile = fs.openSync(filePath, 'w');

  fs.writeFileSync(tmpFile, JSON.stringify(updatedFile, null, 2));
}

function consolidateWithExistingTranslations(filePath, fileName, language) {
  const localesDir = path.join(process.cwd(), 'locales');
  const tmpFile = require(filePath);
  const tmpKeys = Object.keys(tmpFile);
  const existingTranslationsPath = path.join(localesDir, language, `${fileName}.json`);
  const englishSourcePath = path.join(localesDir, 'en', `${fileName}.json`);

  if (fs.existsSync(existingTranslationsPath)) {
    const existingTranslationsFile = require(existingTranslationsPath);
    const englishSourceFile = require(englishSourcePath);
    const existingKeys = Object.keys(existingTranslationsFile);
    const matchingKeys = tmpKeys.filter((k) => existingKeys.indexOf(k) > -1);

    for (let i = 0; i < matchingKeys.length; i++) {
      const key = matchingKeys[i];
      const translatedValue = existingTranslationsFile[key];
      const englishValue = englishSourceFile[key];

      if (translatedValue && translatedValue !== englishValue && translatedValue !== key) {
        tmpFile[key] = translatedValue;
      }
    }

    fs.writeFileSync(filePath, JSON.stringify(tmpFile, null, 2));
  }
}

function processFile(fileName, language, i18nextToPo) {
  let tmpFile;

  const localesDir = path.join(process.cwd(), 'locales');
  const i18nFile = path.join(localesDir, 'en', `${fileName}.json`);

  try {
    if (fs.existsSync(i18nFile)) {
      const tmpDir = path.join(localesDir, 'tmp');
      fs.mkdirSync(tmpDir, { recursive: true });

      tmpFile = path.join(tmpDir, `${fileName}.json`);

      removeValues(i18nFile, tmpFile);
      consolidateWithExistingTranslations(tmpFile, fileName, language);

      const poDir = path.join(process.cwd(), 'po-files', language);
      fs.mkdirSync(poDir, { recursive: true });
      i18nextToPo(language, fs.readFileSync(tmpFile), {
        language,
        foldLength: 0,
        ctxSeparator: '~',
      })
        .then(save(path.join(poDir, `${path.basename(fileName)}.po`)))
        .catch((e) => console.error(fileName, e));
    }
  } catch (err) {
    console.error(`Failed to processFile ${fileName}:`, err);
  }

  common.deleteFile(tmpFile);
  console.log(`Processed ${fileName}`);
}

const options = {
  string: ['language', 'file'],
  boolean: ['help'],
  array: ['files'],
  alias: {
    h: 'help',
    f: 'files',
    l: 'language',
  },
  default: {
    files: [],
  },
};

const args = minimist(process.argv.slice(2), options);

async function main() {
  const { i18nextToPo } = await import('i18next-conv');
  if (args.help) {
    console.log(
      "-h: help\n-l: language (i.e. 'ja')\n-f: file name to convert (i.e. 'plugin__your-plugin')",
    );
  } else if (args.files && args.language) {
    if (Array.isArray(args.files)) {
      for (let i = 0; i < args.files.length; i++) {
        processFile(args.files[i], args.language, i18nextToPo);
      }
    } else {
      processFile(args.files, args.language, i18nextToPo);
    }
  }
}

main().catch((e) => console.error(e));
