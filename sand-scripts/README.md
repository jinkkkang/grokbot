# Grok Bot sandbox scripts (study extracts)

## English

Study extracts copied from a live **Grok Bot** box (Debian 13 KVM sandbox). These scripts and modules are part of the **Anysphere / Cursor sand** runtime (startup, lifecycle watches, supervisors, desktop helpers, and box utilities).

**Purpose:** learning and research only — how the box boots, how services are supervised, and how the virtual desktop stack starts.

**Not affiliated** with Anysphere or Cursor. This tree is a snapshot of files found under `/usr/local/bin` (and one `orbitd` start helper under `/usr/local/libexec`). Proprietary code; do not treat this as an official release or redistribution license.

### Layout

| Directory | Contents |
|-----------|----------|
| `boot/` | Box entrypoint, Python lifecycle watches, supervise/start wrappers, orbitd start |
| `desktop/` | Xvfb / VNC / window-manager helpers and desktop-related JS modules |
| `supervisor/` | `sand-supervisor.mjs` and related small modules |
| `utils/` | cgroup helpers, bounded logging, doctor, contract snippet, machine-id |

### Source (on the box)

- Mostly `/usr/local/bin/…`
- `boot/orbitd-start` ← `/usr/local/libexec/sand/orbitd/start`

---

## 中文

从一台正在运行的 **Grok Bot** 沙箱（Debian 13 / KVM）上摘录的脚本，用于学习研究。内容属于 **Anysphere / Cursor sand** 运行时：启动编排、生命周期监控、监督器、桌面辅助与 box 工具。

**用途：** 仅供学习，了解沙箱如何启动、服务如何被监督、虚拟桌面如何拉起。

**与 Anysphere / Cursor 无关的第三方整理。** 源文件主要来自 `/usr/local/bin`（另含 orbitd 启动脚本）。专有代码；本仓库不构成官方发布或再分发许可。

### 目录

| 目录 | 内容 |
|------|------|
| `boot/` | 入口脚本、两个 Python watch、supervise/start 包装、orbitd 启动 |
| `desktop/` | Xvfb / VNC / 窗口管理相关脚本与桌面 JS 模块 |
| `supervisor/` | `sand-supervisor.mjs` 及相关小模块 |
| `utils/` | cgroup、有界日志、doctor、contract、machine-id |

### 源路径

- 多数：`/usr/local/bin/…`
- `boot/orbitd-start` ← `/usr/local/libexec/sand/orbitd/start`
