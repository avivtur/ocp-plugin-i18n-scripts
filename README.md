# ocp-plugin-i18n-scripts

Reusable i18n/localization scripts for OpenShift Console dynamic plugins. Automates the workflow of extracting translation keys, uploading to Memsource/Phrase for professional translation, and downloading the results back into your project.

## Who should use this

Any OpenShift Console dynamic plugin that needs to support multiple languages via the Memsource/Phrase translation platform. This package replaces the need to copy `i18n-scripts/` directories between plugin repositories.

## Prerequisites

- **Node.js** >= 18
- **jq** installed (`brew install jq` on macOS, `yum install jq` on RHEL)
- **memsource-cli** installed and configured (for upload/download commands only)

### Installing memsource-cli

```bash
DIRECTORY="${HOME}/git/memsource-cli-client/"
mkdir -p "$DIRECTORY" && cd "$DIRECTORY"
python3 -m venv --system-site-packages .memsource
source .memsource/bin/activate
pip install -U pip setuptools pbr memsource-cli
```

Create `~/.memsourcerc`:

```bash
source ${HOME}/git/memsource-cli-client/.memsource/bin/activate
export MEMSOURCE_URL="https://cloud.memsource.com/web"
export MEMSOURCE_USERNAME=<your-username>
export MEMSOURCE_PASSWORD="<your-password>"
export MEMSOURCE_TOKEN=$(memsource auth login --user-name $MEMSOURCE_USERNAME --password "${MEMSOURCE_PASSWORD}" -c token -f value)
```

Run `source ~/.memsourcerc` before using upload/download commands.

## Setup

### 1. Install the package

```bash
npm install --save-dev ocp-plugin-i18n-scripts
```

### 2. Create `i18n-scripts.config.json` in your project root

```json
{
  "pluginName": "plugin__your-plugin-name",
  "projectTitle": "[YourProject $VERSION] UI Localization - Sprint $SPRINT/Branch $BRANCH",
  "templateId": "169304",
  "languages": ["ja", "zh-cn", "ko", "fr", "es"],
  "languageAliases": { "zh-cn": "zh" },
  "pluralOverrides": {}
}
```

### 3. Create `i18next-parser.config.ts` in your project root

This config tells i18next-parser how to extract translation keys from your source files. The `CustomJSONLexer` extracts keys matching the `%...%` pattern from plugin extension files. It must be inlined (not imported from a file) because i18next-parser bundles the config as ESM.

```typescript
import type { UserConfig } from 'i18next-parser';

const CustomJSONLexer = {
  extract(content: string): { key: string }[] {
    const keys: { key: string }[] = [];
    try {
      const parsed = JSON.parse(content) as Record<string, unknown>;
      const scan = (obj: unknown): void => {
        if (typeof obj === 'string') {
          const match = obj.match(/^%(?<key>.+)%$/u);
          if (match?.groups?.['key']) {
            keys.push({ key: match.groups['key'] });
          }
        } else if (Array.isArray(obj)) {
          obj.forEach(scan);
        } else if (obj && typeof obj === 'object') {
          Object.values(obj).forEach(scan);
        }
      };
      scan(parsed);
    } catch {
      // not valid JSON, skip
    }
    return keys;
  },
};

const config: UserConfig = {
  createOldCatalogs: false,
  defaultNamespace: 'plugin__your-plugin-name',
  defaultValue(_locale, _namespace, key: string | undefined): string {
    return key ?? '';
  },
  keySeparator: false,
  lexers: {
    default: ['JsxLexer'],
    json: [CustomJSONLexer] as unknown as UserConfig['lexers'],
    tsx: [
      {
        componentFunctions: ['Trans', 'ForkliftTrans'],
        lexer: 'JsxLexer',
      },
    ],
  } as UserConfig['lexers'],
  locales: ['en', 'es', 'fr', 'ja', 'ko', 'zh'],
  namespaceSeparator: '~',
  sort: true,
};

export default config;
```

Adjust the following for your plugin:
- `defaultNamespace` -- set to your plugin's i18next namespace (must match `pluginName` in config)
- `componentFunctions` in the `tsx` lexer -- add any custom `Trans` components your plugin uses
- `locales` -- must match the languages in `i18n-scripts.config.json` (use filesystem names, e.g., `zh` not `zh-cn`)

### 4. Add npm scripts to your `package.json`

```json
{
  "scripts": {
    "i18n": "i18next \"./src/**/*.{js,jsx,ts,tsx}\" ./plugin-extensions.ts [-oc] -c ./i18next-parser.config.ts && ocp-i18n-defaults && ocp-i18n-fix-plurals && ocp-i18n-replace-br",
    "export-pos": "ocp-i18n-export-pos",
    "i18n-to-po": "ocp-i18n-to-po",
    "po-to-i18n": "ocp-i18n-po-to-i18n",
    "memsource-upload": "ocp-i18n-memsource-upload",
    "memsource-download": "ocp-i18n-memsource-download",
    "i18n-dummy-locale": "ocp-i18n-dummy-locale"
  }
}
```

## Configuration Reference

| Field | Required | Description |
|-------|----------|-------------|
| `pluginName` | Yes | The i18next namespace (e.g., `plugin__forklift-console-plugin`). Used to derive locale JSON and PO filenames. |
| `projectTitle` | No | Memsource project title template. Supports `$VERSION`, `$SPRINT`, `$BRANCH` variables. |
| `templateId` | No | Memsource project template ID. |
| `languages` | Yes | Array of target language codes (e.g., `["ja", "zh-cn", "ko", "fr", "es"]`). |
| `languageAliases` | No | Maps language codes to filesystem directory names (e.g., `{"zh-cn": "zh"}`). Used when the Memsource language code differs from the i18next locale directory. |
| `pluralOverrides` | No | Key-value pairs to fix auto-generated pluralizations. Runs after `set-english-defaults`. Example: `{"{{count}} virtual machine selected_other": "{{count}} virtual machines selected"}`. |

## Command Reference

### Key extraction and post-processing

| Command | Description |
|---------|-------------|
| `ocp-i18n-defaults` | Auto-populates English locale values after i18next-parser extracts keys. Handles plural forms via the `pluralize` package. |
| `ocp-i18n-fix-plurals` | Applies plural overrides from config to fix edge cases in auto-generated pluralizations. |
| `ocp-i18n-replace-br` | Replaces `&nbsp;` HTML entities with regular spaces across all locale JSON files. |

### Memsource/Phrase workflow

| Command | Description |
|---------|-------------|
| `ocp-i18n-export-pos` | Exports English locale JSON to PO files for all configured languages. |
| `ocp-i18n-memsource-upload` | Exports PO files and uploads them to Memsource. Usage: `npm run memsource-upload -- -v VERSION -s SPRINT` |
| `ocp-i18n-memsource-download` | Downloads translated PO files from Memsource and converts them back to locale JSON. Usage: `npm run memsource-download -- -p PROJECT_ID` |

### Conversion utilities

| Command | Description |
|---------|-------------|
| `ocp-i18n-to-po` | Converts i18next JSON to PO format. Usage: `ocp-i18n-to-po -f FILENAME -l LANGUAGE` |
| `ocp-i18n-po-to-i18n` | Converts PO files back to i18next JSON. Usage: `ocp-i18n-po-to-i18n -d DIRECTORY -l LANGUAGE` |

### Development utilities

| Command | Description |
|---------|-------------|
| `ocp-i18n-dummy-locale` | Generates dummy locale files for `es` and `fr` by wrapping English strings with visual markers. Useful for testing locale switching without real translations. |

## Typical Workflow

```
1. Develop features with t('...') translation keys
2. Run: npm run i18n                              (extract keys, set defaults)
3. Commit locale file changes
4. Run: source ~/.memsourcerc                     (authenticate)
5. Run: npm run memsource-upload -- -v 2.12 -s 1  (upload to Phrase)
6. Translators review and confirm translations in Phrase
7. Run: npm run memsource-download -- -p PROJECT_ID (download translations)
8. Translations are auto-committed to locales/<lang>/ directories
```

## Migration from local i18n-scripts/

If your project already has a local `i18n-scripts/` directory copied from kubevirt-plugin:

1. Install this package: `npm install --save-dev ocp-plugin-i18n-scripts`
2. Create `i18n-scripts.config.json` with your plugin's settings
3. Update `package.json` scripts to use `ocp-i18n-*` commands (see Setup step 3)
4. Verify outputs match: run both old and new commands, diff the generated PO/JSON files
5. Remove the local `i18n-scripts/` directory
6. Remove local-only devDependencies if no longer needed: `minimist`, `pluralize`, `i18next-conv`

## License

Apache-2.0
