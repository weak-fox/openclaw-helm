# Third-party notice:
# Portions of this script are derived from:
# https://github.com/serhanekicii/openclaw-helm (commit 63041364340b)
# Licensed under MIT. See THIRD_PARTY_NOTICES.md for details.

log() { echo "[$(date -Iseconds)] [init-config] $*"; }

OPENCLAW_HOME_DIR="{{ .Values.openclaw.paths.homeDir }}"
OPENCLAW_CONFIG_PATH="${OPENCLAW_HOME_DIR}/openclaw.json"
HELM_CONFIG_PATH="/config/openclaw.json"
export OPENCLAW_CONFIG_PATH HELM_CONFIG_PATH

log "Starting config initialization"
mkdir -p "${OPENCLAW_HOME_DIR}"
CONFIG_MODE="${CONFIG_MODE:-merge}"

if [ "$CONFIG_MODE" = "merge" ] && [ -f "${OPENCLAW_CONFIG_PATH}" ]; then
  log "Mode: merge - merging Helm config with existing config"
  if node -e "
    const fs = require('fs');
    // Strip JSON5 single-line comments while preserving // inside strings (e.g. URLs)
    const stripComments = (s) => {
      let r = '', q = false, i = 0;
      while (i < s.length) {
        if (q) {
          if (s[i] === '\\\\') { r += s[i] + s[i+1]; i += 2; continue; }
          if (s[i] === '\"') q = false;
          r += s[i++];
        } else if (s[i] === '\"') {
          q = true; r += s[i++];
        } else if (s[i] === '/' && s[i+1] === '/') {
          while (i < s.length && s[i] !== '\n') i++;
        } else { r += s[i++]; }
      }
      return r;
    };
    let existing;
    try {
      existing = JSON.parse(stripComments(fs.readFileSync(process.env.OPENCLAW_CONFIG_PATH, 'utf8')));
    } catch (e) {
      console.error('[init-config] Warning: existing config is not valid JSON, will overwrite');
      process.exit(1);
    }
    const helm = JSON.parse(stripComments(fs.readFileSync(process.env.HELM_CONFIG_PATH, 'utf8')));
    const deepMerge = (target, source) => {
      for (const key of Object.keys(source)) {
        if (source[key] && typeof source[key] === 'object' && !Array.isArray(source[key])) {
          target[key] = target[key] || {};
          deepMerge(target[key], source[key]);
        } else {
          target[key] = source[key];
        }
      }
      return target;
    };
    const merged = deepMerge(existing, helm);
    fs.writeFileSync(process.env.OPENCLAW_CONFIG_PATH, JSON.stringify(merged, null, 2));
  "; then
    log "Config merged successfully"
  else
    log "WARNING: Merge failed (existing config may not be valid JSON), falling back to overwrite"
    cp "${HELM_CONFIG_PATH}" "${OPENCLAW_CONFIG_PATH}"
  fi
else
  if [ ! -f "${OPENCLAW_CONFIG_PATH}" ]; then
    log "Fresh install - writing initial config"
  else
    log "Mode: overwrite - replacing config with Helm values"
  fi
  cp "${HELM_CONFIG_PATH}" "${OPENCLAW_CONFIG_PATH}"
fi
log "Config initialization complete"
