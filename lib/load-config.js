const fs = require('fs');
const path = require('path');

const CONFIG_FILENAME = 'i18n-scripts.config.json';

function loadConfig() {
  const configPath = path.join(process.cwd(), CONFIG_FILENAME);
  if (!fs.existsSync(configPath)) {
    console.error(`Missing ${CONFIG_FILENAME} in project root (${process.cwd()})`);
    process.exit(1);
  }

  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

  const required = ['pluginName', 'languages'];
  for (const field of required) {
    if (!config[field]) {
      console.error(`Missing required field "${field}" in ${CONFIG_FILENAME}`);
      process.exit(1);
    }
  }

  config.languageAliases = config.languageAliases || {};
  config.pluralOverrides = config.pluralOverrides || {};

  return config;
}

module.exports = { loadConfig };
