# novnc-desktop

容器里跑虚拟桌面，同时提供三条入口：

| 能力 | 端口 | 用途 |
|------|------|------|
| **VNC / noVNC** | `6080` | 人在浏览器里看桌面、点 Chromium / Thunar / 终端 |
| **CDP** | `9222` | Chrome DevTools Protocol，给 Playwright / Puppeteer / 自研工具用 |
| **MCP** | `8931` | Playwright MCP（HTTP），AI 客户端通过 MCP 操控**同一只**浏览器 |

底栏：Chromium、Thunar、xfce4-terminal。Chromium 启动时就打开 CDP，MCP 挂在这条 CDP 上，所以 VNC 里看到的页面 = MCP/CDP 操作的页面。

## 构建与运行

```bash
cd novnc-desktop
docker build -t novnc-desktop .
docker run --rm --shm-size=1g \
  -p 6080:6080 \
  -p 9222:9222 \
  -p 8931:8931 \
  novnc-desktop
```

- VNC：http://localhost:6080/vnc.html
- CDP：http://localhost:9222/json/version
- MCP：http://localhost:8931/mcp

## 客户端怎么接

### CDP（Playwright / Puppeteer）

```js
// Playwright
const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
```

### MCP（Cursor / Claude Desktop 等）

把 MCP 指到容器的 HTTP 端点（Playwright MCP `--port` 模式），例如：

```json
{
  "mcpServers": {
    "novnc-browser": {
      "url": "http://127.0.0.1:8931/mcp"
    }
  }
}
```

若客户端只支持 stdio，可在宿主机另开一层转发：

```bash
npx @playwright/mcp@latest --cdp-endpoint=http://127.0.0.1:9222
```

## 环境变量

| 变量 | 默认 | 含义 |
|------|------|------|
| `SCREEN_WIDTH` / `SCREEN_HEIGHT` | 1280 / 800 | 虚拟分辨率 |
| `NOVNC_PORT` | 6080 | noVNC |
| `VNC_PORT` | 5900 | 容器内 RFB |
| `CDP_PORT` | 9222 | 对外 CDP（socat 转发） |
| `CDP_BIND_PORT` | 9223 | Chromium 本机调试口 |
| `MCP_PORT` | 8931 | Playwright MCP HTTP |
| `START_URL` | about:blank | 浏览器初始页 |
| `AUTO_LAUNCH` | 0 | `1` 时再开 Thunar + 终端 |

## 安全提醒

CDP / MCP 都没有鉴权，**不要把 `9222` / `8931` 直接暴露到公网**。本机或内网 + 反向代理鉴权再用。

## 说明

- 务必加 `--shm-size=1g`，否则 Chromium 容易崩。
- 这是 DIY 复刻，不是 Grok Bot 闭源 sand/orbitd 栈的导出。
