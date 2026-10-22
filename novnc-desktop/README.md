# novnc-desktop

容器里跑虚拟桌面（Xvfb + xfwm4 + plank），用浏览器通过 noVNC 操作。
底栏默认三个入口：Chromium、Thunar、xfce4-terminal。

## 构建与运行

```bash
cd novnc-desktop
docker build -t novnc-desktop .
docker run --rm -p 6080:6080 --shm-size=1g novnc-desktop
```

浏览器打开：http://localhost:6080/vnc.html  
（若连不上可试 `http://localhost:6080/vnc.html?autoconnect=1&resize=scale`）

## 常用环境变量

| 变量 | 默认 | 含义 |
|------|------|------|
| `SCREEN_WIDTH` / `SCREEN_HEIGHT` | 1280 / 800 | 虚拟分辨率 |
| `NOVNC_PORT` | 6080 | 网页端口 |
| `VNC_PORT` | 5900 | 容器内 VNC 端口 |
| `AUTO_LAUNCH` | 0 | 设为 `1` 时自动打开文件管理器和终端 |

示例：

```bash
docker run --rm -p 6080:6080 --shm-size=1g \
  -e SCREEN_WIDTH=1920 -e SCREEN_HEIGHT=1200 \
  -e AUTO_LAUNCH=1 \
  novnc-desktop
```

## 挂载工作目录（可选）

```bash
docker run --rm -p 6080:6080 --shm-size=1g \
  -v "$PWD/work:/home/desktop/work" \
  novnc-desktop
```

## 说明

- Chromium 在容器里建议保留 `--shm-size=1g`，否则标签页容易崩。
- 需要 Google Chrome 官方包时，自行改 Dockerfile 加 Google apt 源，并把 launcher 换成 `google-chrome`。
- 这只复刻「网页里看到桌面」；侧边文件树 / 嵌入式终端要另加 Web 服务。
