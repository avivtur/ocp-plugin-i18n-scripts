#!/usr/bin/env bash

set -exuo pipefail

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

SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"

if [[ "$OSTYPE" == "darwin"* ]]; then
  SED_INPLACE=(sed -i '' -E)
else
  SED_INPLACE=(sed -i -r)
fi

for f in locales/en/* ; do
  for i in "${LANGUAGES[@]}"
  do
    node "${SCRIPT_DIR}/../lib/i18n-to-po.js" -f "$(basename "$f" .json)" -l "$i"

    case $i in
      es) pattern='plural=(n != 1)' ;;
      fr) pattern='plural=(n >= 2)' ;;
      *) pattern='plural=0' ;;
    esac

    file="./po-files/$i/${PLUGIN_NAME}.po"
    "${SED_INPLACE[@]}" "s|${pattern}|${pattern};|g" "$file"
    "${SED_INPLACE[@]}" 's|;;|;|g' "$file"

  done
done
