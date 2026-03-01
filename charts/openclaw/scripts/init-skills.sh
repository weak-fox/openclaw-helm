log() { echo "[$(date -Iseconds)] [init-skills] $*"; }

OPENCLAW_HOME="{{ .Values.openclaw.paths.home }}"
OPENCLAW_HOME_DIR="{{ .Values.openclaw.paths.homeDir }}"
OPENCLAW_WORKSPACE_DIR="{{ .Values.openclaw.paths.workspaceDir }}"
OPENCLAW_EXTENSIONS_DIR="${OPENCLAW_HOME_DIR}/extensions"

log "Starting skills initialization"

if [ "${BOOTSTRAP_MODE:-offline}" = "offline" ]; then
  log "Bootstrap mode=offline, running seed-init.sh"
  exec /usr/local/bin/seed-init.sh
fi

# ============================================================
# Runtime Dependencies
# ============================================================
# Some skills require additional runtimes (Python, Go, etc.)
# Install them here so they persist across pod restarts.
#
# Example: Install uv (Python package manager) for Python skills
# mkdir -p "${OPENCLAW_HOME_DIR}/bin"
# if [ ! -f "${OPENCLAW_HOME_DIR}/bin/uv" ]; then
#   log "Installing uv..."
#   curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="${OPENCLAW_HOME_DIR}/bin" sh
# fi
#
# Example: Install pnpm and packages for interfaces (e.g., MS Teams)
# The read-only filesystem and non-root UID prevent writing to default
# pnpm paths (/usr/local/lib/node_modules, ~/.local/share/pnpm, etc.).
# Redirect PNPM_HOME to the PVC so the binary persists across restarts.
# The init container's HOME=/tmp ensures pnpm's cache, state, and config
# writes land on /tmp (writable emptyDir). The store goes on the PVC so
# hardlinks work (same filesystem as node_modules) and persist.
# PNPM_HOME="${OPENCLAW_HOME_DIR}/pnpm"
# mkdir -p "$PNPM_HOME"
# if [ ! -f "$PNPM_HOME/pnpm" ]; then
#   log "Installing pnpm..."
#   curl -fsSL https://get.pnpm.io/install.sh | env PNPM_HOME="$PNPM_HOME" SHELL=/bin/sh sh -
# fi
# export PATH="$PNPM_HOME:$PATH"
# log "Installing interface dependencies..."
# cd "${OPENCLAW_HOME_DIR}"
# pnpm install <your-package> --store-dir "${OPENCLAW_HOME_DIR}/.pnpm-store"

# ============================================================
# Skill Installation
# ============================================================
# Install skills from ClawHub (https://clawhub.com)
mkdir -p "${OPENCLAW_WORKSPACE_DIR}/skills"
cd "${OPENCLAW_WORKSPACE_DIR}"
if [ "${SKILLS_INSTALL_ENABLED:-true}" = "true" ]; then
  if [ -n "${SKILLS_INSTALL_ITEMS:-}" ]; then
    for skill in ${SKILLS_INSTALL_ITEMS}; do
      if [ -n "$skill" ] && [ ! -d "skills/${skill##*/}" ]; then
        log "Installing skill: $skill"
        if ! npx -y clawhub install "$skill" --no-input; then
          log "WARNING: Failed to install skill: $skill"
        fi
      else
        log "Skill already installed: $skill"
      fi
    done
  else
    log "No skills configured for installation"
  fi
else
  log "Skill installation disabled"
fi

# ============================================================
# Plugin Installation
# ============================================================
# Official OpenClaw approach for external tool integration:
# install a plugin and expose tools via plugins.entries.<id>.
if [ "${PLUGINS_INSTALL_ENABLED:-true}" != "true" ]; then
  log "Plugin installation disabled"
else
  plugin_lines="$(
    PLUGINS_INSTALL_ITEMS_JSON="${PLUGINS_INSTALL_ITEMS_JSON:-[]}" node -e '
      const raw = process.env.PLUGINS_INSTALL_ITEMS_JSON || "[]";
      let items = [];
      try { items = JSON.parse(raw); } catch { process.exit(1); }
      if (!Array.isArray(items)) process.exit(1);
      for (const item of items) {
        const id = item?.id ? String(item.id) : "";
        const spec = item?.onlineSpec ? String(item.onlineSpec) : "";
        const offlineMode = item?.offlineMode ? String(item.offlineMode) : "";
        console.log(`${id}|${spec}|${offlineMode}`);
      }
    '
  )" || plugin_lines=""

  if [ -z "$plugin_lines" ]; then
    log "No plugins configured for installation"
  else
    printf '%s\n' "$plugin_lines" | while IFS='|' read -r PLUGIN_ID PLUGIN_SPEC PLUGIN_OFFLINE_MODE; do
      PLUGIN_DIR="${OPENCLAW_EXTENSIONS_DIR}/${PLUGIN_ID}"

      if [ -z "$PLUGIN_ID" ]; then
        log "Skipping plugin with empty id"
      elif [ -d "$PLUGIN_DIR" ]; then
        log "Plugin already installed: $PLUGIN_ID"
      elif [ "${BOOTSTRAP_MODE:-offline}" = "online" ]; then
        if [ -n "$PLUGIN_SPEC" ]; then
          log "Installing plugin: $PLUGIN_ID ($PLUGIN_SPEC)"
          # Use a minimal config during install to avoid bootstrap
          # cycles when openclaw.json already references this plugin.
          echo '{}' > /tmp/openclaw.plugins-install.json
          if ! OPENCLAW_CONFIG_PATH=/tmp/openclaw.plugins-install.json NPM_CONFIG_CACHE=/tmp/.npm npm_config_cache=/tmp/.npm node /app/openclaw.mjs plugins install "$PLUGIN_SPEC"; then
            log "WARNING: Failed to install plugin: $PLUGIN_ID ($PLUGIN_SPEC)"
          fi
        else
          log "WARNING: No onlineSpec defined for plugin: $PLUGIN_ID"
        fi
      else
        log "Offline mode expects preinstalled plugin: $PLUGIN_ID (offlineMode=${PLUGIN_OFFLINE_MODE:-preinstalled})"
      fi
    done
  fi
fi

log "Skills initialization complete"
