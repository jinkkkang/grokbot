#!/usr/bin/env bash
set -euo pipefail

DISPLAY="${DISPLAY:-:1}"
SCREEN_WIDTH="${SCREEN_WIDTH:-1280}"
SCREEN_HEIGHT="${SCREEN_HEIGHT:-800}"
SCREEN_DEPTH="${SCREEN_DEPTH:-24}"
VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
HOME="${HOME:-/home/desktop}"
export DISPLAY HOME
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg-runtime}"
export PYTHONNOUSERSITE=1

mkdir -p "${XDG_RUNTIME_DIR}" "${HOME}/.config" /tmp
chmod 700 "${XDG_RUNTIME_DIR}" || true

cleanup() {
  echo "[desktop] shutting down..."
  jobs -pr | xargs -r kill 2>/dev/null || true
  wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Session bus (Thunar / xfce apps expect it)
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
  eval "$(dbus-launch --sh-syntax)"
  export DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID
fi

echo "[desktop] starting Xvfb ${DISPLAY} ${SCREEN_WIDTH}x${SCREEN_HEIGHT}x${SCREEN_DEPTH}"
Xvfb "${DISPLAY}" -screen 0 "${SCREEN_WIDTH}x${SCREEN_HEIGHT}x${SCREEN_DEPTH}" \
  -ac +extension GLX +render -noreset &
XVFB_PID=$!

# Wait until the display is ready
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

# Dark-ish solid background (no wallpaper package needed)
xsetroot -solid "#2b2b2b" || true

echo "[desktop] window manager + compositor + dock"
xfwm4 --compositor=off &
picom --backend xrender --vsync --no-fading-openclose 2>/dev/null &
# Plank settings: keep dock items, hide less aggressively
if command -v dconf >/dev/null 2>&1; then
  dconf write /net/launchpad/plank/docks/dock1/dock-items \
    "['chrome.dockitem', 'thunar.dockitem', 'xfce4-terminal.dockitem']" || true
  dconf write /net/launchpad/plank/docks/dock1/hide-mode "'intelligent'" || true
fi
plank --name dock1 &

echo "[desktop] x11vnc on :${VNC_PORT}"
x11vnc -display "${DISPLAY}" \
  -rfbport "${VNC_PORT}" \
  -localhost \
  -nopw \
  -shared \
  -forever \
  -noxdamage \
  -norc \
  -quiet &

# Prefer packaged noVNC web root
NOVNC_WEB=""
for cand in /usr/share/novnc /usr/share/novnc/utils/..; do
  if [ -f "${cand}/vnc.html" ]; then
    NOVNC_WEB="${cand}"
    break
  fi
done
if [ -z "${NOVNC_WEB}" ]; then
  echo "[desktop] noVNC web root not found" >&2
  exit 1
fi

echo "[desktop] noVNC http://0.0.0.0:${NOVNC_PORT}/vnc.html (→ localhost:${VNC_PORT})"
websockify --web="${NOVNC_WEB}" --heartbeat=30 \
  "0.0.0.0:${NOVNC_PORT}" "localhost:${VNC_PORT}" &
WEBSOCKIFY_PID=$!

# Optional: auto-open apps on first boot (set AUTO_LAUNCH=1)
if [ "${AUTO_LAUNCH:-0}" = "1" ]; then
  sleep 1
  thunar "${HOME}" &
  xfce4-terminal &
fi

echo "[desktop] ready. Open http://<host>:${NOVNC_PORT}/vnc.html"
# Keep the container alive on the noVNC proxy; if it dies, exit
wait "${WEBSOCKIFY_PID}"
