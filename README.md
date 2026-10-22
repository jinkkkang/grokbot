# Grok Bot Debian 沙箱学习指南

本仓库是一台 **Grok Bot** 沙箱的学习材料：仓库根目录是 **2026-10-18** 在容器内采集的脱敏系统快照（`sysinfo`），[`sand-scripts/`](sand-scripts/) 是容器里的启动与监督脚本，[`docs/boot-chain/`](docs/boot-chain/BOOT-CHAIN-FULL.md) 是客户机底座从 Firecracker 到 isod、runc 的启动链和原始 unit。三份材料放在一起，用来回答「机器怎么起来、每个脚本在干什么」。

这是 **学习摘录**，不是官方发行版，也 **不构成再分发许可**。脚本属于 Anysphere / Cursor 的 sand 运行时，专有代码。本仓库与 Anysphere / Cursor 无隶属关系。快照里没有密钥、cookie、grant 文件，也没有放进任何二进制。

采集时刻：`2026-10-18 18:35:26 CST`。主机名 `grok-bot-vm-477963022`。容器内是 Debian 13（trixie），内核 `6.12.94+`。底座是 Debian 12。

---

## 怎么读这个仓库

按这个顺序，可以从「这是什么机器」读到「某一行脚本为什么存在」：

1. **本页的架构总览和端口表。** 先建立容器内的启动链和名词，再翻文件。
2. **[`docs/boot-chain/BOOT-CHAIN-FULL.md`](docs/boot-chain/BOOT-CHAIN-FULL.md)。** 客户机怎么从 Firecracker 走到 systemd、isod、runc，再进入本页描述的容器。原始 unit、脚本和脱敏 OCI/runc state 在 [`docs/boot-chain/artifacts/`](docs/boot-chain/artifacts/)。
3. **[`SUMMARY.md`](SUMMARY.md)。** 中文结论：采集点在 KVM 客户机内部的 runc 容器里；cmdline 与当前根不一致的原因；谁真正拉起业务进程。
4. **[`process/boot-chain-verify.txt`](process/boot-chain-verify.txt)** 和 **[`process/classification.md`](process/classification.md)。** 采集当时的进程树，用来核对文档，而不是当成永远不变的现场。
5. **[`disk/root-vda-vs-vdb.txt`](disk/root-vda-vs-vdb.txt)** 配 **[`virt/dmesg-root-disk.txt`](virt/dmesg-root-disk.txt)。** 只在你要搞清根盘时读。机制以启动链全文第 3、5 节为准。
6. **[`sand-scripts/README.md`](sand-scripts/README.md)。** 容器内启动时序图、四个子目录、`supervise-*` 和 `start-*` 怎么配合。
7. **按调用顺序读脚本：** [`start-sand-box`](sand-scripts/boot/start-sand-box) → [`sand-exit-watch`](sand-scripts/boot/sand-exit-watch) → 某一个 `supervise-*` → 它包住的 `start-*`。桌面单独看 [`start-desktop.sh`](sand-scripts/desktop/start-desktop.sh)。
8. **端口对不上号时回到本页的端口表**，再打开 [`sand-scripts/utils/box-contract.generated.mjs`](sand-scripts/utils/box-contract.generated.mjs)。那份生成文件是端口的权威对照，脚本里的数字应当和它一致。

脚本顶部的中文块注释解释「这一段为什么存在」。原有英文注释保留，逻辑没有改写。

---

## 底座启动链（Firecracker → isod → runc）

本页其余部分是在 **容器里面** 看到的。容器的 `/` 是 `/dev/vdb`，容器的 PID 1 是 `tini`。客户机本身还有一层：Firecracker 把 Debian 12 底座挂在 `/dev/vda` 上，那里的 PID 1 是 **systemd**。

完整叙事、流程图和证据索引在 [`docs/boot-chain/BOOT-CHAIN-FULL.md`](docs/boot-chain/BOOT-CHAIN-FULL.md)。原始 unit、底座脚本、isod 的 hash / `--help` / RPC 列表、脱敏 OCI 与 runc state、容器内脚本原文，在 [`docs/boot-chain/artifacts/`](docs/boot-chain/artifacts/)。

| 本仓库已经记下来的现象 | 底座侧对应 |
|------------------------|------------|
| cmdline 仍是 `root=/dev/vda`，`df` 的 `/` 是 vdb | 内核挂的是底座。vdb 成为 `/` 发生在 **runc 的容器 mount namespace**（`pivot_root`）。客户机上的 systemd 仍以 vda 为根 |
| 容器 PID 1 = `tini` → `pod-daemon` | 客户机 PID 1 = systemd。tini 是容器 init，由 isod 调 runc 拉起 |
| `ss` 看到 **2375**、**50052**、**26500**，进程列为空 | 容器与底座共享网络命名空间。2375 是 `docker-socat`，50052 是 `isod`，26500 与 `pod-daemon` 的默认 gRPC 地址一致（本实例 argv 没有 `--listen-addr`） |

isod、pod-daemon、NVIDIA 用户态 `.so` 没有进仓库，只有 hash、`--help`、unit 和脚本。OCI 里的 token 写成 `<redacted>`。[`sand-scripts/`](sand-scripts/) 仍是带中文注释的阅读版；[`docs/boot-chain/artifacts/container-scripts/`](docs/boot-chain/artifacts/container-scripts/) 是其中一部分脚本的原文。

---

## 架构总览

下面这张图是 **容器内部**。沙箱跑在 KVM 客户机里。容器 PID 1 是 `tini`，它只负责拉起 **一个** 子进程、转发信号、收尸。业务服务不是 tini 枚举出来的。客户机底座的 systemd / isod / runc 见上一节。

```text
客户机（Firecracker）
  systemd 为 PID 1，根是 /dev/vda
  isod 调 runc，在新 mount namespace 里 pivot_root
        │
        ▼
容器
  / 来自 /dev/vdb
        │
        ▼
tini                         容器 PID 1。只 exec /pod-daemon
        │
        ▼
pod-daemon                   沙箱运行时。由它创建容器内进程
        │
        ├── start-sand-box   一次性编排。准备目录、身份、cgroup，fork 各服务
        │         │
        │         └── exec 替换成 sand-exit-watch（bash 自身不再留下）
        │
        └── cursor-agent-store-fuse
              把 agent store 挂到 /cursor/stores（快照里可见，脚本不在本仓库）
```

`start-sand-box` 在 exec 之前放到后台的，大致是这几类：

| 角色 | 进程 | 挂了会怎样 |
|------|------|------------|
| 生命周期主人 | `supervise-exec-daemon` → `start-exec-daemon`（`:1337`） | `sand-exit-watch` 结束整个 box |
| 生命周期主人（开启时） | `supervise-sand-supervisor` → `sand-supervisor.mjs` | 同上 |
| 镜像内 daemon | 例如 `orbitd`，由 `sand-exit-watch` 按 `--daemon-launcher` 拉起 | 只重启该 daemon，不结束 box |
| 共享设施 | window router、fork noVNC、session-sync、cookie、UA governor | 自己退出不结束 box |
| 桌面 | `start-desktop.sh`（`:1`） | 超时只记 `desktop` 失败，不因此跳过后面的 exec |
| 观测 | `sand-memory-watch`、`box-doctor` | 采样或自检失败不拆 box |

采集当时核对过的实况见 [`process/boot-chain-verify.txt`](process/boot-chain-verify.txt)：PID 1 是 `tini`，PID 7 是 `pod-daemon`，其下是 `sand-exit-watch`（参数里带 `--exec-owner`、`--supervise-owner` 和 `orbitd=.../orbitd/start`）。挂在 PID 1 下的 `dbus-daemon` / `dconf` / `bamf` 是桌面会话孤儿被 init 收养，不是 tini 主动启动的服务。

`tini` 版本 0.19.0（MIT，上游 krallin/tini）。`pod-daemon` 是专有二进制，本仓库只有路径和 sha256，见 [`binaries/binary-notes.txt`](binaries/binary-notes.txt)。

---

## 根盘：cmdline 写 vda，df 看到 vdb

[`disk/root-vda-vs-vdb.txt`](disk/root-vda-vs-vdb.txt) 和 [`virt/dmesg-root-disk.txt`](virt/dmesg-root-disk.txt) 记的是同一次采集：

1. 内核按 cmdline 把 **`/dev/vda`** 挂成初始根。dmesg：`VFS: Mounted root ... on device 254:0`（vda 的主次设备号）。
2. 随后 **`/dev/vdb`** 以另一套 UUID 挂上（`EXT4-fs (vdb): mounted`）。
3. runc 在容器 mount namespace 里切根之后，容器内 `findmnt /` 和 `df` 的 `/` 都是 vdb。`/proc/cmdline` 是启动参数快照，不会被改写，所以仍写 `root=/dev/vda`。
4. `/etc/fstab` 是 `UNCONFIGURED FSTAB`，不是 fstab 把根指到 vdb。两块盘都是 128GiB virtio 盘，UUID 不同，不是同一个文件系统的两个名字。
5. 采集时 `blkid` 不在 PATH，[`disk/blkid.txt`](disk/blkid.txt) 为空；UUID 以 dmesg 摘录为准。底座侧补全的 UUID 见 [`docs/boot-chain/BOOT-CHAIN-FULL.md`](docs/boot-chain/BOOT-CHAIN-FULL.md) 第 5 节。

这五条是容器内能直接核对的现象。切根的执行者是底座上的 **runc**（`no_pivot_root: false`），范围是新建的 mount namespace。客户机 systemd 的根一直是 vda；分析时把 vda 再挂进容器，挂载点是 `/mnt/vda`。

---

## 目录地图

仓库有三棵采集与阅读树，职责不要混。旁边另有一份可独立构建的配方 [`novnc-desktop/`](novnc-desktop/)，不属于这三棵树。

| 树 | 是什么 | 怎么用 |
|----|--------|--------|
| **仓库根（sysinfo）** | 某一时刻的只读命令输出：进程、磁盘、网络、包列表。采集点在容器内 | 核对「当时容器里长什么样」。会过期 |
| **[`sand-scripts/`](sand-scripts/)** | 从 `/usr/local/bin`（以及一处 libexec）抄出的文本脚本，加了中文注释 | 读「代码打算怎么启动」。路径在沙箱里是 `/usr/local/bin/...`，在本仓库里多了一层 `sand-scripts/<子目录>/` |
| **[`docs/boot-chain/`](docs/boot-chain/BOOT-CHAIN-FULL.md)** | 客户机底座启动链，加上 unit、底座脚本、脱敏 OCI / runc state | 先读全文，再按第 8 节进 [`artifacts/`](docs/boot-chain/artifacts/) |
| **[`novnc-desktop/`](novnc-desktop/)** | 自行构建的网页桌面配方（noVNC 6080、CDP 9222、MCP 8931），不是采集快照 | 想在 Docker 里得到同一只浏览器的桌面、CDP 和 MCP 时再读 |

根上的 [`MANIFEST.txt`](MANIFEST.txt) 只覆盖 sysinfo，**不含** `sand-scripts/`。脚本树自己的清单是 [`sand-scripts/MANIFEST.txt`](sand-scripts/MANIFEST.txt)（注释写明生成时的 size/sha256；本指南往脚本里加了中文注释之后，那些哈希不再等于工作区）。

`sand-scripts/` 四个子目录：

| 子目录 | 角色 |
|--------|------|
| `boot/` | 编排入口、两个 Python watch、`supervise-*` / `start-*`、orbitd 启动器 |
| `desktop/` | 主桌面与 fork 窗口：Xvfb、VNC、窗口管理、路由 |
| `supervisor/` | `sand-supervisor.mjs` 和它拆出去的策略模块 |
| `utils/` | cgroup、有界日志、开机自检、machine-id、生成的端口契约 |

子目录怎么配合、`supervise-*` 和 `start-*` 的分工，写在 [`sand-scripts/README.md`](sand-scripts/README.md)。

---

## 自己搭网页桌面（DIY）

[`novnc-desktop/`](novnc-desktop/) 是一份自包含的 Docker 配方，用来在浏览器里得到相近的桌面：Chromium、Thunar 文件管理器、xfce4-terminal。镜像基于 Debian bookworm，会话是 Xvfb + xfwm4 + plank。同一只 Chromium 有三条入口：noVNC `6080`、CDP `9222`（Chromium 听 localhost:9223，由 socat 发布到 0.0.0.0:9222）、Playwright MCP `8931`（`--cdp-endpoint http://127.0.0.1:9223`）。底栏浏览器走 `/usr/local/bin/box-chrome`，共用 `--user-data-dir`。构建和运行写在 [`novnc-desktop/README.md`](novnc-desktop/README.md)。

这是用发行版软件包做的简化重做。它不是闭源 sand / orbitd 栈的转储，也不包含 [`sand-scripts/desktop/`](sand-scripts/desktop/) 里采集来的专有启动脚本。

---

## 名词

脚本里的名字和日常说法不完全一样，读代码时用这一组：

| 词 | 在本仓库里的意思 |
|----|------------------|
| **box** | 这台沙箱虚拟机；也指里面的用户 `box`（agent 的 shell、桌面、exec-daemon） |
| **host / sand-host** | 沙箱 **内部** 的 host 进程和账号（`/opt/sand/sand-host`）。不是外面的 hypervisor |
| **uid split** | `SAND_HOST_UID_SPLIT=1` 且探测通过时，host 跑 `sand-host`，agent 仍是 `box` |
| **pod-daemon** | tini 的唯一子进程，沙箱运行时。由它（代表宿主机）创建 `start-sand-box` |
| **lifecycle owner** | `supervise-exec-daemon` 的 PID，以及开了 supervisor 时 `supervise-sand-supervisor` 的 PID。任一退出，box 结束 |
| **primary desktop** | `DISPLAY=:1`。VNC `5900`，noVNC `6080` |
| **fork window** | `:2` 起的额外桌面。exec-daemon 端口 `14000+屏号`，VNC `5900+屏号` |
| **镜像内 daemon** | 例如 orbitd。启动器在 `/usr/local/libexec/sand/<服务>/start`，由 `sand-exit-watch` 拉起，而不是由 `supervise-*` 拉起 |

---

## 端口

契约数字来自 [`sand-scripts/utils/box-contract.generated.mjs`](sand-scripts/utils/box-contract.generated.mjs)。「快照」列是 [`network/ss-lntp.txt`](network/ss-lntp.txt) 在采集时看到的监听；桌面和浏览器数量会变，所以多出来的屏号是现场，不是常量。

| 端口 | 名字 | 谁在听 | 快照 |
|------|------|--------|------|
| **1337** | primary exec-daemon | `start-exec-daemon` | 在听 |
| **1338** | primary PTY WebSocket | 同一个 exec-daemon | 在听 |
| **1339** | window router | `sand-window-router.mjs`，把请求转到 1337 或 `14000+屏号` | 在听 |
| **1340** | in-box host gateway | host 进程（`sand-supervisor` 管它的生命周期） | 在听 |
| **5900** | 主桌面 VNC | `x11vnc`，只绑 localhost | 在听 |
| **5900+N** | fork 窗口 VNC | N 为屏号，例如 `:2` → 5902 | 看到 5902、5903 |
| **6080** | 主桌面 noVNC | `websockify` → `localhost:5900` | 在听 |
| **6081** | fork 窗口 noVNC | 带 token 文件的 `websockify` | 在听 |
| **8790** | egress tunnel WebSocket | `sand-egress-tunnel`（`SAND_EGRESS_TUNNEL_ENABLED=1` 才起） | 在听 |
| **8791** | egress CONNECT 代理 | 同一隧道进程，只绑 127.0.0.1 | 在听 |
| **9222+屏号** | Chrome DevTools | 浏览器；`sand-memory-watch` 用它数标签页 | 看到 9224 |
| **14000+N** | fork exec-daemon | `start-window` 为该屏另起一份 | 看到 14002、14003 |
| **13600+N** | fork PTY WebSocket | 同上 | 看到 13602、13603 |

另外：`pod-daemon` 的命令行带 `--ssh-auth-vsock-port 52`，那是 vsock，不是上表里的 TCP。采集时 `ss` 还看到 **2375**、**50052**、**26500**，进程列为空。底座材料把它们对上了：2375 是 `docker-socat` 把 docker.sock 转到 TCP，50052 是 `isod`，26500 是 `pod-daemon` 的默认 gRPC 地址。容器和底座共享网络命名空间，所以容器内的 `ss` 听得到底座上的端口。见 [`docs/boot-chain/BOOT-CHAIN-FULL.md`](docs/boot-chain/BOOT-CHAIN-FULL.md)。

---

## 全文件清单

下面每个 sysinfo 与 `sand-scripts/` 文件一行。`docs/boot-chain/` 不逐条列入，目录职责见 [`docs/boot-chain/BOOT-CHAIN-FULL.md`](docs/boot-chain/BOOT-CHAIN-FULL.md) 第 8 节。

### 根目录与系统快照

| 文件 | 这一份是干什么的 |
|------|------------------|
| `README.md` | 本学习指南：架构、端口、目录和全文件清单 |
| `SUMMARY.md` | 中文分析摘要：KVM、vda/vdb、tini → pod-daemon → start-sand-box |
| `CAPTURED_AT.txt` | 采集时间：2026-10-18 18:35:26 CST |
| `MANIFEST.txt` | sysinfo 文件名列表（不含 `sand-scripts/`） |
| `REDACTIONS.md` | 刻意没采集的内容：environ、grant、cookie、密钥 |
| `uname.txt` | `uname -a`：主机名与内核版本 |
| `hostname.txt` | 主机名 `grok-bot-vm-477963022` |
| `os-release.txt` | Debian 13 (trixie) 发行信息 |
| `cmdline.txt` | `/proc/cmdline`，其中 `root=/dev/vda` 是启动参数，不是当前根 |
| `machine-id.txt` | 本 VM 的 machine-id（本地标识，不是凭据） |
| `env-sanitized.txt` | 只保留 USER/HOME/PATH/TZ 等非密钥环境 |
| `meminfo.txt` | `/proc/meminfo`：约 16GiB 内存，SwapTotal 为 0 |
| `mounts.txt` | `/proc/mounts` |
| `cpuinfo-summary.txt` | 各逻辑 CPU 的型号与 flags，含 `hypervisor` |
| `etc/os-release` | 与 `os-release.txt` 相同的发行信息副本 |
| `etc/hosts` | 把本机主机名指到 127.0.0.1 |
| `etc/resolv.conf` | DNS：`nameserver 10.0.0.2` |

### `binaries/`、`disk/`、`virt/`

| 文件 | 这一份是干什么的 |
|------|------------------|
| `binaries/binary-notes.txt` | `/tini`、`/pod-daemon`、两个关键脚本的 sha256，以及 tini 0.19.0 版本输出 |
| `disk/df.txt` | `df`：当前根是 `/dev/vdb`，约 125G |
| `disk/lsblk.txt` | `vda` 与 `vdb` 各 128G；只有 vdb 挂在 `/` |
| `disk/partitions.txt` | `/proc/partitions`：两块 virtio 盘的扇区数 |
| `disk/findmnt.txt` | 挂载树；`/cursor/stores` 是 agent-store FUSE |
| `disk/root-vda-vs-vdb.txt` | cmdline、findmnt、stat、设备号的对照记录 |
| `disk/blkid.txt` | 打算记 blkid；采集时命令不在 PATH，文件为空 |
| `virt/virt-clues.txt` | KVM / virtio 证据：无 `/.dockerenv`，dmesg 写明 Hypervisor detected: KVM |
| `virt/dmesg-root-disk.txt` | 内核先挂 vda（254:0），再挂 vdb 的几行 dmesg |

### `network/`、`packages/`、`proc/`、`process/`

| 文件 | 这一份是干什么的 |
|------|------------------|
| `network/ip-addr.txt` | `lo`、`enp0s4`（172.30.0.2/24）、`docker0`（172.17.0.1/16，无载波） |
| `network/ip-route.txt` | 默认路由经 172.30.0.1 |
| `network/ss-lntp.txt` | 采集时的 TCP 监听，端口表的「快照」列来自这里 |
| `packages/dpkg-ii-names.txt` | 约 665 个状态为 `ii` 的包名 |
| `packages/dpkg-l-head.txt` | `dpkg -l` 表头，以及总行数 672 |
| `packages/key-packages.txt` | Chrome、Python、nodejs、Xvfb、x11vnc、websockify 等关键包与路径 |
| `proc/cpuinfo-full.txt` | 完整 `/proc/cpuinfo` |
| `proc/cpuinfo-head.txt` | cpuinfo 开头若干颗 CPU |
| `process/boot-chain-verify.txt` | PID 1/7 命令行，以及 `start-sand-box` 里和监督、exec 相关的行号 |
| `process/classification.md` | 约 160 个进程按 agent、浏览器、桌面、生命周期等分类 |
| `process/ps-auxww.txt` | `ps auxww` 全表 |
| `process/pstree.txt` | 完整进程树 |
| `process/pid1-cmdline.txt` | `/tini -- /pod-daemon ... --ssh-auth-vsock-port 52` |
| `process/pid1-status.txt` | `/proc/1/status` |
| `process/pid1-cgroup.txt` | tini 所在 cgroup（`system.slice/pod-...`） |
| `process/pid1-exe.txt` | `/proc/1/exe` 因权限不可读的记录 |

### `sand-scripts/boot/`

| 文件 | 这一份是干什么的 |
|------|------------------|
| `sand-scripts/MANIFEST.txt` | 脚本树的 size 与 sha256 清单（加注释之前的摘录） |
| `sand-scripts/README.md` | 脚本阅读指南：时序图、子目录、supervise 与 start 的关系 |
| `sand-scripts/boot/start-sand-box` | 用户态编排：准备环境、fork 服务，最后 exec 成 `sand-exit-watch` |
| `sand-scripts/boot/sand-exit-watch` | Python subreaper：收尸、盯两个 owner、按 launcher 拉起 orbitd 一类 daemon |
| `sand-scripts/boot/sand-memory-watch` | 按 Chrome/host/桌面分桶采样 PSS 与 CPU，追加到遥测日志 |
| `sand-scripts/boot/supervise-exec-daemon` | 重启循环：清掉占着 1337 的旧进程，拉起并探活 exec-daemon |
| `sand-scripts/boot/start-exec-daemon` | 一次启动：丢掉 token，在 `/workspace` 跑 `exec-daemon serve` |
| `sand-scripts/boot/supervise-egress-tunnel` | 重启循环：盯隧道 WebSocket 端口，探活并退避重启 |
| `sand-scripts/boot/start-egress-tunnel` | 一次启动：`exec sand-egress-tunnel server` |
| `sand-scripts/boot/supervise-sand-supervisor` | 重启循环：盯 `status.json` 是否还在更新，必要时结束 box |
| `sand-scripts/boot/orbitd-start` | orbitd 的 launcher：经 `sand-daemon-supervisor` 启动，日志走有界日志 |

### `sand-scripts/desktop/`

| 文件 | 这一份是干什么的 |
|------|------------------|
| `sand-scripts/desktop/start-desktop.sh` | 拉起主桌面：Xvfb、x11vnc、noVNC、xfwm4、picom、Plank，然后 `tail -f` 占住会话 |
| `sand-scripts/desktop/start-window` | 为 `:2` 及以上再开一套桌面和 exec-daemon；拒绝动主屏 |
| `sand-scripts/desktop/stop-window` | 停掉或挂起一个 fork 窗口；拒绝停主屏 |
| `sand-scripts/desktop/box-xvfb` | 先清掉同屏号上仍占着 abstract socket 的旧 Xvfb，再 exec 真 Xvfb |
| `sand-scripts/desktop/box-x11vnc` | 先清掉占用目标 RFB 端口的旧 x11vnc，再启动 |
| `sand-scripts/desktop/box-xfwm4` | 按 DISPLAY 与 exe 身份清掉旧窗口管理器，再启动 |
| `sand-scripts/desktop/box-picom` | 清掉同 DISPLAY 的旧 picom，再启动 |
| `sand-scripts/desktop/box-plank` | 等合成器选区 `_NET_WM_CM_S0` 出现后，再启动 dock |
| `sand-scripts/desktop/sand-desktop-supervise.sh` | 被 source：把组件的 pid、日志、重启命令登记到 `/tmp/sand-desktop` |
| `sand-scripts/desktop/sand-desktop-unit.sh` | 被 source：按 Chrome profile 找出一个桌面单元的 pid 并发信号 |
| `sand-scripts/desktop/sand-window-router.mjs` | 听 1339，用 display / owner token 把 HTTP 转到主或 fork exec-daemon |
| `sand-scripts/desktop/sand-supervisor-desktop.mjs` | 桌面组件的重启判定、健康快照、重拉时的环境清理 |
| `sand-scripts/desktop/sand-supervisor-rfb-handshake.mjs` | 做一次最小 RFB 握手，用来判断 fork 窗口的 VNC 链断在哪一截 |

### `sand-scripts/supervisor/` 与 `sand-scripts/utils/`

| 文件 | 这一份是干什么的 |
|------|------------------|
| `sand-scripts/supervisor/sand-supervisor.mjs` | 监督进程入口：tick 循环，管 host 启停/升级、桌面健康、状态文件 |
| `sand-scripts/supervisor/sand-supervisor-contract.mjs` | 目录、角色（host/desktop）、命令种类等契约常量 |
| `sand-scripts/supervisor/sand-supervisor-host-policy.mjs` | host 升级是否该等空闲、崩溃怎么分类、退避多久 |
| `sand-scripts/supervisor/sand-supervisor-host-bundle.mjs` | 把下载的 host bundle 解到暂存目录再换上 `/opt/sand` |
| `sand-scripts/supervisor/sand-supervisor-process-identity.mjs` | 用 `/proc/pid/cmdline` 确认监听者是预期进程，避免误杀 |
| `sand-scripts/supervisor/sand-supervisor-cgroup-accounting.mjs` | 解析 cgroup v2 的 `cpu.stat` / `cpu.pressure` 做采样 |
| `sand-scripts/utils/box-cgroups.sh` | 建立 `interactive` / `agent` / `background` 三个 cpu 权重组 |
| `sand-scripts/utils/box-bounded-log` | bash 包装：把一条命令的 stdout/stderr 送进有界日志 |
| `sand-scripts/utils/box-bounded-log.mjs` | 环形缓冲，把单个日志文件截在上限内并轮转 |
| `sand-scripts/utils/box-contract.generated.mjs` | 从上游 box-contract 生成的端口、屏号基数和标记路径 |
| `sand-scripts/utils/box-doctor` | 开机自检：machine-id、Chrome、出口、时钟、D-Bus、Xvfb/VNC/noVNC/合成器 |
| `sand-scripts/utils/ensure-machine-id` | 保证 `/etc/machine-id` 是 32 位小写十六进制，并与 D-Bus 那份对齐 |

上表覆盖 sysinfo 与 `sand-scripts/`（写这份指南时与当时 `git ls-tree` 的 78 个文件一致）。`docs/boot-chain/` 是后来补上的底座链路，不重复进这张表。

---

## 局限

- 进程列表和监听端口是采集瞬间。多开的 Chrome / fork 窗口会改变 5900+N、14000+N 和 CDP 端口。
- 未采集 `/proc/*/environ`、pod grant、浏览器配置里的秘密。见 [`REDACTIONS.md`](REDACTIONS.md)。
- `pod-daemon`、`exec-daemon`、`sand-egress-tunnel`、`orbitd`、`isod` 本体不在本仓库。底座侧补充了 hash、`--help`、unit 和脱敏 JSON，见 [`docs/boot-chain/artifacts/`](docs/boot-chain/artifacts/)。
- 根目录 [`MANIFEST.txt`](MANIFEST.txt) 与 [`sand-scripts/MANIFEST.txt`](sand-scripts/MANIFEST.txt) 是摘录时的清单，不是本指南改注释之后的哈希。

---

## English (secondary)

This repo is a study snapshot of a Grok Bot sandbox: a Debian 13 root inside a runc container, on a Debian 12 Firecracker guest, plus the text scripts that boot the container. It is a proprietary study extract, not an open-source release and not an Anysphere/Cursor product drop.

The guest is a Firecracker microVM. Its real PID 1 is systemd on a Debian 12 root (`/dev/vda`). `isod` (`0.0.0.0:50052`) hydrates a rootfs and asks `runc` 1.3.6 to `pivot_root` into a container whose root is `/dev/vdb`. Inside that container, PID 1 is `tini`, which runs only `/pod-daemon`. The pod daemon starts `start-sand-box`. That script prepares users, cgroups, and directories, forks long-running services, and **execs** `sand-exit-watch`. The exit watch is a Python subreaper: it reaps children, restarts image daemons such as orbitd, and ends the box when the exec-daemon supervisor (and, when enabled, the sand-supervisor supervisor) exits.

The full chain, with units and redacted OCI/runc state, is [`docs/boot-chain/BOOT-CHAIN-FULL.md`](docs/boot-chain/BOOT-CHAIN-FULL.md). Raw artifacts live in [`docs/boot-chain/artifacts/`](docs/boot-chain/artifacts/). Listeners **2375**, **50052**, and **26500** are docker-socat, isod, and pod-daemon's default gRPC address; the container shares the guest network namespace, which is why `ss` inside the container sees them.

Read [`sand-scripts/README.md`](sand-scripts/README.md) for the in-container sequence diagram. The file table above inventories the sysinfo snapshot and `sand-scripts/`; `docs/boot-chain/` is listed in the boot-chain doc. Ports 1337/1338 are the primary exec daemon, 1339 the window router, 5900/6080 the primary VNC/noVNC pair, 6081 fork noVNC, 8790/8791 the egress tunnel, 14000+N and 13600+N fork exec/PTY, 9222+display Chrome CDP.

[`novnc-desktop/`](novnc-desktop/) is a separate DIY recipe for a similar browser, file manager, and terminal desktop in Docker. The same headed Chromium is reachable over noVNC on port 6080, CDP on 9222 (Chromium listens on localhost:9223; socat publishes 0.0.0.0:9222), and Playwright MCP on 8931. It is not a dump of the closed sand/orbitd stack.
