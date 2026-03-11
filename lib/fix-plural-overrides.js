#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { loadConfig } = require('./load-config.js');

const config = loadConfig();
const pluginName = config.pluginName;
const overrides = config.pluralOverrides || {};

const LOCALE_FILE = path.join(process.cwd(), 'locales', 'en', `${pluginName}.json`);

if (Object.keys(overrides).length === 0) {
  console.log('No plural overrides configured.');
  process.exit(0);
}

const localeData = JSON.parse(fs.readFileSync(LOCALE_FILE, 'utf8'));

let fixCount = 0;

for (const [key, correctValue] of Object.entries(overrides)) {
  if (key in localeData && localeData[key] !== correctValue) {
    localeData[key] = correctValue;
    fixCount++;
    console.log(`Fixed: "${key}" -> "${correctValue}"`);
  }
}

if (fixCount > 0) {
  fs.writeFileSync(LOCALE_FILE, JSON.stringify(localeData, null, 2));
  console.log(`Applied ${fixCount} plural override(s).`);
} else {
  console.log('No plural overrides needed.');
}
