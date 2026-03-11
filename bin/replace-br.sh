#!/usr/bin/env bash

CONFIG="./i18n-scripts.config.json"

if [ ! -f "$CONFIG" ]; then
  echo "Error: Missing $CONFIG in project root" >&2
  exit 1
fi

PLUGIN_NAME=$(jq -r '.pluginName' "$CONFIG")
LANGUAGES=()
while IFS= read -r lang; do
  LANGUAGES+=("$lang")
done < <(jq -r '.languages[]' "$CONFIG")
ALIASES=$(jq -r '.languageAliases // {}' "$CONFIG")

resolve_lang() {
  local lang="$1"
  local alias
  alias=$(echo "$ALIASES" | jq -r --arg l "$lang" '.[$l] // empty')
  if [ -n "$alias" ]; then
    echo "$alias"
  else
    echo "$lang"
  fi
}

LOCALE_FILES=("./locales/en/${PLUGIN_NAME}.json")
for lang in "${LANGUAGES[@]}"; do
  dir_lang=$(resolve_lang "$lang")
  LOCALE_FILES+=("./locales/${dir_lang}/${PLUGIN_NAME}.json")
done

EXISTING_FILES=()
for f in "${LOCALE_FILES[@]}"; do
  if [ -f "$f" ]; then
    EXISTING_FILES+=("$f")
  fi
done

if [ ${#EXISTING_FILES[@]} -gt 0 ]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' -E "s| | |g" "${EXISTING_FILES[@]}"
  else
    sed -i -r "s| | |g" "${EXISTING_FILES[@]}"
  fi
fi
