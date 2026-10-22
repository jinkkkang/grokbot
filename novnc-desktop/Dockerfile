# Lightweight web desktop: Xvfb + XFCE bits + noVNC
# Build:  docker build -t novnc-desktop .
# Run:    docker run --rm -p 6080:6080 --shm-size=1g novnc-desktop
# Open:   http://localhost:6080/vnc.html

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
    HOME=/home/desktop \
    USER=desktop

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dbus-x11 \
        fonts-dejavu-core \
        fonts-noto-cjk \
        novnc \
        picom \
        plank \
        procps \
        python3-numpy \
        thunar \
        websockify \
        x11-utils \
        x11-xserver-utils \
        x11vnc \
        xfce4-terminal \
        xfwm4 \
        xvfb \
        chromium \
    && rm -rf /var/lib/apt/lists/*

# Non-root user for the desktop session
RUN useradd -m -s /bin/bash -u 1000 desktop \
    && mkdir -p /home/desktop/.config/plank/dock1/launchers \
                /home/desktop/.local/share/applications \
                /tmp/xdg-runtime \
    && chown -R desktop:desktop /home/desktop /tmp/xdg-runtime

# Browser launcher (Chromium; rename class so Plank matches)
RUN printf '%s\n' \
      '[Desktop Entry]' \
      'Version=1.0' \
      'Type=Application' \
      'Name=Browser' \
      'Comment=Chromium' \
      'Exec=/usr/bin/chromium --no-first-run --disable-dev-shm-usage --class=box-chrome %U' \
      'Icon=chromium' \
      'Terminal=false' \
      'Categories=Network;WebBrowser;' \
      'StartupWMClass=box-chrome' \
      'MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;' \
      > /home/desktop/.local/share/applications/box-chrome.desktop \
    && chown desktop:desktop /home/desktop/.local/share/applications/box-chrome.desktop

# Plank dock items: Browser / Files / Terminal
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

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 6080

USER desktop
WORKDIR /home/desktop

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
