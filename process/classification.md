# Process classification (snapshot)
Total processes sampled: 160

## Agent / exec runtime (63)
- `flock -n /tmp/novnc-forks.log.lock /exec-daemon/node /usr/local/bin/box-bounded-log.mjs /tmp/novnc-forks.log 204`
- `/exec-daemon/node /usr/local/bin/box-bounded-log.mjs /tmp/novnc-forks.log 204`
- `/exec-daemon/node /usr/local/bin/sand-window-router.mjs 1339 1337 14000`
- `/exec-daemon/node /usr/local/bin/sand-session-sync.mjs`
- `/exec-daemon/node /usr/local/bin/sand-web-bot-auth.mjs`
- `bash /usr/local/bin/box-bounded-log --run /tmp/sand-web-bot-auth.log -- /exec-daemon/node /usr/local/bin/sand-web-bot-au`
- `flock -n /tmp/sand-web-bot-auth.log.lock /exec-daemon/node /usr/local/bin/box-bounded-log.mjs /tmp/sand-web-bot-auth.log`
- `/exec-daemon/node /usr/local/bin/box-bounded-log.mjs /tmp/sand-web-bot-auth.log 249`
- `/exec-daemon/node /usr/local/bin/sand-ua-governor.mjs`
- `bash /usr/local/bin/box-bounded-log --run /tmp/sand-ua-governor.log -- /exec-daemon/node /usr/local/bin/sand-ua-governor`
- `flock -n /tmp/sand-ua-governor.log.lock /exec-daemon/node /usr/local/bin/box-bounded-log.mjs /tmp/sand-ua-governor.log 2`
- `/exec-daemon/node /usr/local/bin/box-bounded-log.mjs /tmp/sand-ua-governor.log 287`
- `/exec-daemon/node /usr/local/bin/sand-cookie-persist.mjs`
- `bash /usr/local/bin/supervise-exec-daemon 1337 /usr/local/bin/start-exec-daemon`
- `bash /usr/local/bin/start-exec-daemon`
- … and 48 more

## Browser (Chrome) (14)
- `/opt/google/chrome/chrome --no-sandbox --disable-dev-shm-usage --password-store=basic --no-first-run --no-default-browse`
- `bash /usr/local/bin/box-bounded-log --run /tmp/chrome:2.log -- env -u TZ -u SAND_GATEWAY_TOKEN -u SAND_EGRESS_TUNNEL_BEA`
- `/opt/google/chrome/chrome_crashpad_handler --monitor-self --monitor-self-annotation=ptype=crashpad-handler --database=/h`
- `/opt/google/chrome/chrome_crashpad_handler --no-periodic-tasks --monitor-self-annotation=ptype=crashpad-handler --databa`
- `/opt/google/chrome/chrome --type=zygote --no-zygote-sandbox --no-sandbox --crashpad-handler-pid=0 --enable-crash-reporte`
- `/opt/google/chrome/chrome --type=zygote --no-sandbox --crashpad-handler-pid=0 --enable-crash-reporter=, --user-data-dir=`
- `/opt/google/chrome/chrome --type=utility --utility-sub-type=network.mojom.NetworkService --lang=en-US --service-sandbox-`
- `/opt/google/chrome/chrome --type=utility --utility-sub-type=storage.mojom.StorageService --lang=en-US --service-sandbox-`
- `/opt/google/chrome/chrome --type=renderer --crashpad-handler-pid=0 --enable-crash-reporter=, --user-data-dir=/home/box/c`
- `/opt/google/chrome/chrome --type=gpu-process --gpu-recent-crash-count=0 --no-sandbox --disable-dev-shm-usage --ozone-pla`
- `/opt/google/chrome/chrome --type=renderer --top-chrome-webui --crashpad-handler-pid=0 --enable-crash-reporter=, --user-d`
- `/opt/google/chrome/chrome --type=renderer --crashpad-handler-pid=0 --enable-crash-reporter=, --user-data-dir=/home/box/c`
- `/opt/google/chrome/chrome --type=renderer --crashpad-handler-pid=0 --enable-crash-reporter=, --user-data-dir=/home/box/c`
- `/opt/google/chrome/chrome --type=renderer --crashpad-handler-pid=0 --enable-crash-reporter=, --user-data-dir=/home/box/c`

## Desktop / VNC / noVNC (41)
- `/usr/bin/python3 /usr/bin/websockify --web=/usr/share/novnc --heartbeat=30 --token-plugin TokenFile --token-source /tmp/`
- `bash /usr/local/bin/box-bounded-log --run /tmp/novnc-forks.log -- /usr/bin/websockify --web=/usr/share/novnc --heartbeat`
- `bash /usr/local/bin/start-desktop.sh`
- `bash /usr/local/bin/box-bounded-log --run /tmp/start-desktop.log -- /usr/local/bin/start-desktop.sh`
- `Xvfb :1 -screen 0 1920x1200x24 -ac +extension GLX +render -noreset`
- `bash /usr/local/bin/box-bounded-log --run /tmp/xvfb:1.log -- /usr/local/bin/box-xvfb :1 -screen 0 1920x1200x24 -ac +exte`
- `x11vnc -skip_lockkeys -display :1 -localhost -nopw -shared -forever -noxdamage -rfbport 5900 -quiet`
- `bash /usr/local/bin/box-bounded-log --run /tmp/x11vnc:1.log -- /usr/local/bin/box-x11vnc -display :1 -localhost -nopw -s`
- `/usr/bin/python3 /usr/bin/websockify --web=/usr/share/novnc --heartbeat=30 0.0.0.0:6080 localhost:5900`
- `bash /usr/local/bin/box-bounded-log --run /tmp/novnc:1.log -- websockify --web=/usr/share/novnc --heartbeat=30 0.0.0.0:6`
- `xfwm4 --compositor=off`
- `bash /usr/local/bin/box-bounded-log --run /tmp/xfwm4:1.log -- /usr/local/bin/box-xfwm4 --compositor=off`
- `picom --backend xrender --no-vsync --no-frame-pacing --no-use-damage`
- `bash /usr/local/bin/box-bounded-log --run /tmp/picom:1.log -- /usr/local/bin/box-picom --backend xrender --no-vsync --no`
- `plank --name dock1`
- … and 26 more

## Desktop session helpers (dbus/dconf) (12)
- `/usr/bin/dbus-daemon --syslog --fork --print-pid 4 --print-address 6 --session`
- `/usr/libexec/dconf-service`
- `/bin/bash /usr/libexec/bamf/bamfdaemon-dbus-runner`
- `/usr/libexec/bamf/bamfdaemon`
- `/usr/bin/dbus-daemon --syslog --fork --print-pid 4 --print-address 6 --session`
- `/usr/libexec/dconf-service`
- `/bin/bash /usr/libexec/bamf/bamfdaemon-dbus-runner`
- `/usr/libexec/bamf/bamfdaemon`
- `/usr/bin/dbus-daemon --syslog --fork --print-pid 4 --print-address 6 --session`
- `/usr/libexec/dconf-service`
- `/bin/bash /usr/libexec/bamf/bamfdaemon-dbus-runner`
- `/usr/libexec/bamf/bamfdaemon`

## Idle / keep-alive (7)
- `bash -c while sleep "$1"; do kill -USR1 "$2" 2>/dev/null || exit 0; done ticker 5 456`
- `tail -f /dev/null`
- `tail -f /dev/null`
- `tail -f /dev/null`
- `sleep 5`
- `sleep 2`
- `sleep 2`

## Init / sandbox core (2)
- `/tini -- /pod-daemon --ssh-auth-sock-path /run/host-services/ssh-auth.sock --ssh-auth-vsock-port 52`
- `/pod-daemon --ssh-auth-sock-path /run/host-services/ssh-auth.sock --ssh-auth-vsock-port 52`

## Other (3)
- `cat`
- `cat`
- `ps auxww`

## Sandbox lifecycle / watchers (11)
- `/usr/bin/python3 /usr/local/bin/sand-exit-watch --telemetry-log /tmp/sand-box-telemetry.log --exec-owner 338 --supervise`
- `/exec-daemon/node /exec-daemon/index.js serve --port 1337 --pty-websocket-port 1338 --auth-token local --rg-path /exec-d`
- `/usr/bin/python3 /usr/local/bin/sand-memory-watch --telemetry-log /tmp/sand-box-telemetry.log`
- `/usr/local/libexec/sand/sand-daemon-supervisor run orbitd`
- `bash /usr/local/bin/box-bounded-log --run /tmp/sand-orbitd.log -- env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/`
- `flock -n /tmp/sand-orbitd.log.lock /exec-daemon/node /usr/local/bin/box-bounded-log.mjs /tmp/sand-orbitd.log 637`
- `/exec-daemon/node /usr/local/bin/box-bounded-log.mjs /tmp/sand-orbitd.log 637`
- `/usr/local/libexec/sand/sand-daemon-supervisor __supervise orbitd`
- `/var/lib/sand-daemon-supervisor/orbitd/releases/28b0833c5707e1c919cee4d4ab5a8ad0eeac9c46/orbitd`
- `/exec-daemon/node /exec-daemon/index.js serve --port 14002 --pty-websocket-port 13602 --auth-token local --rg-path /exec`
- `/exec-daemon/node /exec-daemon/index.js serve --port 14003 --pty-websocket-port 13603 --auth-token local --rg-path /exec`

## Shell / scripts (7)
- `bash /usr/local/bin/supervise-egress-tunnel 8790 /usr/local/bin/start-egress-tunnel`
- `[bash] <defunct>`
- `[bash] <defunct>`
- `bash`
- `[bash] <defunct>`
- `bash`
- `/usr/bin/bash -O extglob -c IFS= builtin read -r -d '' __cursor_command <&5 2>/dev/null || { builtin printf '%s\n' 'The `
