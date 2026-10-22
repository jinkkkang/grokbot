#!/usr/bin/env bash
set -euo pipefail

DISPLAY="${DISPLAY:-:1}"
SCREEN_WIDTH="${SCREEN_WIDTH:-1280}"
SCREEN_HEIGHT="${SCREEN_HEIGHT:-800}"
SCREEN_DEPTH="${SCREEN_DEPTH:-24}"
VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
CDP_PORT="${CDP_PORT:-9222}"
CDP_BIND_PORT="${CDP_BIND_PORT:-9223}"   # Chromium listens on localhost only
MCP_PORT="${MCP_PORT:-8931}"
HOME="${HOME:-/home/desktop}"
CHROME_USER_DATA_DIR="${CHROME_USER_DATA_DIR:-${HOME}/chrome-profile}"
START_URL="${START_URL:-about:blank}"

export DISPLAY HOME CHROME_USER_DATA_DIR CDP_PORT
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg-runtime}"
export PYTHONNOUSERSITE=1
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

mkdir -p "${XDG_RUNTIME_DIR}" "${HOME}/.config" "${CHROME_USER_DATA_DIR}" /tmp
chmod 700 "${XDG_RUNTIME_DIR}" || true

cleanup() {
  echo "[desktop] shutting down..."
  jobs -pr | xargs -r kill 2>/dev/null || true
  wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
  eval "$(dbus-launch --sh-syntax)"
  export DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID
fi

echo "[desktop] starting Xvfb ${DISPLAY} ${SCREEN_WIDTH}x${SCREEN_HEIGHT}x${SCREEN_DEPTH}"
Xvfb "${DISPLAY}" -screen 0 "${SCREEN_WIDTH}x${SCREEN_HEIGHT}x${SCREEN_DEPTH}" \
  -ac +extension GLX +render -noreset &

for _ in $(seq 1 50); do
  if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
if ! xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
  echo "[desktop] Xvfb failed to become ready" >&2
  exit 1
fi

xsetroot -solid "#2b2b2b" || true

echo "[desktop] window manager + compositor + dock"
xfwm4 --compositor=off &
picom --backend xrender --vsync --no-fading-openclose 2>/dev/null &
if command -v dconf >/dev/null 2>&1; then
  dconf write /net/launchpad/plank/docks/dock1/dock-items \
    "['chrome.dockitem', 'thunar.dockitem', 'xfce4-terminal.dockitem']" || true
fi
plank --name dock1 &

# --- VNC / noVNC ---
echo "[vnc] x11vnc on :${VNC_PORT}"
x11vnc -display "${DISPLAY}" \
  -rfbport "${VNC_PORT}" \
  -localhost \
  -nopw \
  -shared \
  -forever \
  -noxdamage \
  -norc \
  -quiet &

NOVNC_WEB=""
for cand in /usr/share/novnc /usr/share/novnc/utils/..; do
  if [ -f "${cand}/vnc.html" ]; then
    NOVNC_WEB="${cand}"
    break
  fi
done
[ -n "${NOVNC_WEB}" ] || { echo "[vnc] noVNC web root not found" >&2; exit 1; }

echo "[vnc] noVNC http://0.0.0.0:${NOVNC_PORT}/vnc.html"
websockify --web="${NOVNC_WEB}" --heartbeat=30 \
  "0.0.0.0:${NOVNC_PORT}" "localhost:${VNC_PORT}" &
WEBSOCKIFY_PID=$!

# --- CDP: Chromium with remote debugging on localhost, socat exposes it ---
echo "[cdp] starting Chromium (debug port ${CDP_BIND_PORT} → publish ${CDP_PORT})"
/usr/bin/chromium \
  --no-first-run \
  --no-default-browser-check \
  --disable-dev-shm-usage \
  --disable-gpu \
  --disable-software-rasterizer \
  --class=box-chrome \
  --user-data-dir="${CHROME_USER_DATA_DIR}" \
  --remote-debugging-port="${CDP_BIND_PORT}" \
  --remote-debugging-address=127.0.0.1 \
  "${START_URL}" &

# Wait for CDP HTTP endpoint
for _ in $(seq 1 100); do
  if curl -fsS "http://127.0.0.1:${CDP_BIND_PORT}/json/version" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
if ! curl -fsS "http://127.0.0.1:${CDP_BIND_PORT}/json/version" >/dev/null 2>&1; then
  echo "[cdp] Chromium CDP did not become ready on ${CDP_BIND_PORT}" >&2
  exit 1
fi

# Publish CDP on 0.0.0.0:CDP_PORT (Chromium itself often refuses non-localhost)
socat "TCP-LISTEN:${CDP_PORT},fork,reuseaddr,bind=0.0.0.0" \
  "TCP:127.0.0.1:${CDP_BIND_PORT}" &
echo "[cdp] ready at http://0.0.0.0:${CDP_PORT}/json/version"

# --- MCP: Playwright MCP attached to the same Chromium via CDP ---
MCP_BIN=""
if command -v mcp-server-playwright >/dev/null 2>&1; then
  MCP_BIN=(mcp-server-playwright)
elif [ -x /usr/lib/node_modules/@playwright/mcp/cli.js ]; then
  MCP_BIN=(node /usr/lib/node_modules/@playwright/mcp/cli.js)
elif [ -x /usr/local/lib/node_modules/@playwright/mcp/cli.js ]; then
  MCP_BIN=(node /usr/local/lib/node_modules/@playwright/mcp/cli.js)
else
  MCP_BIN=(npx --yes @playwright/mcp@latest)
fi

echo "[mcp] Playwright MCP on 0.0.0.0:${MCP_PORT} → cdp http://127.0.0.1:${CDP_BIND_PORT}"
"${MCP_BIN[@]}" \
  --host 0.0.0.0 \
  --port "${MCP_PORT}" \
  --cdp-endpoint "http://127.0.0.1:${CDP_BIND_PORT}" \
  --allowed-hosts '*' &
MCP_PID=$!

if [ "${AUTO_LAUNCH:-0}" = "1" ]; then
  sleep 1
  thunar "${HOME}" &
  xfce4-terminal &
fi

echo "[desktop] ready"
echo "  VNC  http://<host>:${NOVNC_PORT}/vnc.html"
echo "  CDP  http://<host>:${CDP_PORT}/json/version"
echo "  MCP  http://<host>:${MCP_PORT}/mcp  (Playwright MCP HTTP)"

# Stay up while noVNC is alive; MCP crash should not kill the desktop
wait "${WEBSOCKIFY_PID}"
