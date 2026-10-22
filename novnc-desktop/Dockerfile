# Web desktop with VNC + CDP + MCP
# Build:  docker build -t novnc-desktop .
# Run:    docker run --rm -p 6080:6080 -p 9222:9222 -p 8931:8931 --shm-size=1g novnc-desktop
# VNC:    http://localhost:6080/vnc.html
# CDP:    http://localhost:9222/json/version
# MCP:    http://localhost:8931/mcp  (Playwright MCP over HTTP, attached to CDP)

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    DISPLAY=:1 \
    SCREEN_WIDTH=1280 \
    SCREEN_HEIGHT=800 \
    SCREEN_DEPTH=24 \
    VNC_PORT=5900 \
    NOVNC_PORT=6080 \
    CDP_PORT=9222 \
    MCP_PORT=8931 \
    HOME=/home/desktop \
    USER=desktop \
    CHROME_USER_DATA_DIR=/home/desktop/chrome-profile \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        chromium \
        curl \
        dbus-x11 \
        fonts-dejavu-core \
        fonts-noto-cjk \
        gnupg \
        novnc \
        picom \
        plank \
        procps \
        python3-numpy \
        socat \
        thunar \
        websockify \
        x11-utils \
        x11-xserver-utils \
        x11vnc \
        xfce4-terminal \
        xfwm4 \
        xvfb \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g @playwright/mcp@latest \
    && rm -rf /var/lib/apt/lists/* /root/.npm

# Non-root user for the desktop session
RUN useradd -m -s /bin/bash -u 1000 desktop \
    && mkdir -p /home/desktop/.config/plank/dock1/launchers \
                /home/desktop/.local/share/applications \
                /home/desktop/chrome-profile \
                /tmp/xdg-runtime \
    && chown -R desktop:desktop /home/desktop /tmp/xdg-runtime

# Dock launcher opens a new window on the shared CDP Chromium profile
RUN printf '%s\n' \
      '[Desktop Entry]' \
      'Version=1.0' \
      'Type=Application' \
      'Name=Browser' \
      'Comment=Chromium (CDP enabled)' \
      'Exec=/usr/local/bin/box-chrome %U' \
      'Icon=chromium' \
      'Terminal=false' \
      'Categories=Network;WebBrowser;' \
      'StartupWMClass=box-chrome' \
      'MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;' \
      > /home/desktop/.local/share/applications/box-chrome.desktop \
    && chown desktop:desktop /home/desktop/.local/share/applications/box-chrome.desktop

RUN printf '%s\n' \
      '[PlankDockItemPreferences]' \
      'Launcher=file:///home/desktop/.local/share/applications/box-chrome.desktop' \
      > /home/desktop/.config/plank/dock1/launchers/chrome.dockitem \
    && printf '%s\n' \
      '[PlankDockItemPreferences]' \
      'Launcher=file:///usr/share/applications/thunar.desktop' \
      > /home/desktop/.config/plank/dock1/launchers/thunar.dockitem \
    && printf '%s\n' \
      '[PlankDockItemPreferences]' \
      'Launcher=file:///usr/share/applications/xfce4-terminal.desktop' \
      > /home/desktop/.config/plank/dock1/launchers/xfce4-terminal.dockitem \
    && chown -R desktop:desktop /home/desktop/.config

# Wrapper: same user-data-dir so dock clicks join the CDP browser
COPY box-chrome /usr/local/bin/box-chrome
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/box-chrome /usr/local/bin/entrypoint.sh \
    && test -d /usr/lib/node_modules/@playwright/mcp \
       -o -d /usr/local/lib/node_modules/@playwright/mcp \
       -o -x "$(command -v mcp-server-playwright || true)"

EXPOSE 6080 9222 8931

USER desktop
WORKDIR /home/desktop

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
