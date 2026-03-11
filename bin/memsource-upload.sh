#!/usr/bin/env bash

set -exuo pipefail

CONFIG="./i18n-scripts.config.json"

if [ ! -f "$CONFIG" ]; then
  echo "Error: Missing $CONFIG in project root" >&2
  exit 1
fi

LANGUAGES=()
while IFS= read -r lang; do
  LANGUAGES+=("$lang")
done < <(jq -r '.languages[]' "$CONFIG")
PROJECT_TITLE_TEMPLATE=$(jq -r '.projectTitle // ""' "$CONFIG")
TEMPLATE_ID=$(jq -r '.templateId // ""' "$CONFIG")

SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"

while getopts v:s: flag
do
  case "${flag}" in
    v) VERSION=${OPTARG};;
    s) SPRINT=${OPTARG};;
    *) echo "usage: $0 [-v] [-s]" >&2
       exit 1;;
  esac
done

BRANCH=$(git branch --show-current)

TITLE=$(echo "$PROJECT_TITLE_TEMPLATE" | sed \
  -e "s/\\\$VERSION/$VERSION/g" \
  -e "s/\\\$SPRINT/$SPRINT/g" \
  -e "s/\\\$BRANCH/$BRANCH/g")

echo "Creating project with title \"$TITLE\""

echo "Exporting PO files"
"${SCRIPT_DIR}/export-pos.sh"
echo "Exported all PO files"

CREATE_ARGS=(memsource project create --name "$TITLE" -f json)
if [ -n "$TEMPLATE_ID" ]; then
  CREATE_ARGS+=(--template-id "$TEMPLATE_ID")
fi

PROJECT_INFO=$("${CREATE_ARGS[@]}")
PROJECT_ID=$(echo "$PROJECT_INFO" | jq -r '.uid')

echo "Creating jobs for exported PO files"
for i in "${LANGUAGES[@]}"
do
  memsource job create --filenames po-files/"$i"/*.po --target-langs "$i" --project-id "${PROJECT_ID}"
done

echo "Uploaded PO files to Memsource"

rm -rf po-files
