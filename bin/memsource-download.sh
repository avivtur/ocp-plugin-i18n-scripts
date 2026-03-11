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
ALIASES=$(jq -r '.languageAliases // {}' "$CONFIG")

SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"

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

while getopts p: flag
do
  case "${flag}" in
    p) PROJECT_ID=${OPTARG};;
    *) echo "usage: $0 [-p]" >&2
       exit 1;;
  esac
done

echo "Checking if git workspace is clean"
GIT_STATUS="$(git status --short --untracked-files -- locales)"
if [ -n "$GIT_STATUS" ]; then
  echo "There are uncommitted files in locales folders. Remove or commit the files, then run this script again."
  git diff
  exit 1
fi

echo "Downloading PO files from Project ID \"$PROJECT_ID\""

DOWNLOAD_PATH="$(mktemp -d)" || { echo "Failed to create temp folder"; exit 1; }

for i in "${LANGUAGES[@]}"
do
  COUNTER=0
  CURRENT_PAGE=( $(memsource job list --project-id "$PROJECT_ID" --target-lang "$i" -f value --page-number 0 -c uid) )
  until [ -z "$CURRENT_PAGE" ]
  do
    ((COUNTER++))
    echo Downloading page "$COUNTER"
    memsource job download --project-id "$PROJECT_ID" --output-dir "$DOWNLOAD_PATH/$i" --job-id "${CURRENT_PAGE[@]}"
    CURRENT_PAGE=$(memsource job list --project-id "$PROJECT_ID" --target-lang "$i" -f value --page-number "$COUNTER" -c uid | tr '\n' ' ')
  done
done

echo Importing downloaded PO files
for i in "${LANGUAGES[@]}"
do
  dir_lang=$(resolve_lang "$i")
  node "${SCRIPT_DIR}/../lib/po-to-i18n.js" -d "$DOWNLOAD_PATH/$i" -l "$dir_lang"
done

"${SCRIPT_DIR}/replace-br.sh"

echo Creating commit
git add locales
git commit -m "chore(i18n): update translations

Adding latest translations from Memsource project https://cloud.memsource.com/web/project2/show/$PROJECT_ID

Resolves: None"
