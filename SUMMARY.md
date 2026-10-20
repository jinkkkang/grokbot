# 系统分析摘要（中文）

采集时间见 `CAPTURED_AT.txt`。以下结论基于本目录内的只读证据，并在采集时重新核对。采集点在 **容器内部**。客户机底座（Debian 12、systemd、isod、runc）见 [`docs/boot-chain/BOOT-CHAIN-FULL.md`](docs/boot-chain/BOOT-CHAIN-FULL.md)。

## 1. 环境定性

- 采集点在 **KVM 客户机内部的 runc 容器**里。客户机不是裸机。这个容器不是 Docker/Podman 起的（无 `/.dockerenv`、无 `/run/.containerenv`），是底座 `isod` 调 `runc` 起的。
- 证据：`/proc/cmdline` 含 `clocksource=kvm-clock`、`root=/dev/vda`、`console=ttyS0`；CPU 有 `hypervisor`；磁盘为 virtio（`vda`/`vdb`）。
- 主机名形如 `grok-bot-vm-*`。容器内 PID 1 为 `tini`，子进程为 `/pod-daemon`。客户机 PID 1 是 vda 上的 systemd；本快照进不去那个 pid namespace。

## 2. 为何 cmdline 写 root=/dev/vda，而 df 显示 vdb？

内核没有把设备改名。它先把 vda 挂成客户机根；之后底座上的 runc 在 **容器的 mount namespace** 里 `pivot_root`，容器内的 `/` 才来自 vdb。客户机 systemd 的根一直是 vda。

1. 内核按 cmdline 把 **`/dev/vda`** 挂为初始根（dmesg：`VFS: Mounted root ... on device 254:0`，即 vda）。
2. 随后 **`/dev/vdb`** 被挂上（dmesg 中有 `EXT4-fs (vdb): mounted ...`）。
3. runc 在容器 mount namespace 里 `pivot_root` 之后，**容器内当前** `/` 来自 vdb；`findmnt /`、`df`、`stat /` 均指向 vdb。底座 systemd 的 `/` 仍是 vda。分析时 vda 被另挂到容器内 `/mnt/vda`。
4. `/proc/cmdline` 是启动参数快照，**不会**随后改写，故仍显示 `root=/dev/vda`。
5. `/proc/fs/ext4/` 下同时可见 `vda` 与 `vdb`：两块盘的 ext4 都还被内核记着。容器可见挂载树里的 `/` 是 vdb；vda 是底座的根，分析时另挂在 `/mnt/vda`。
6. `/etc/fstab` 为 `UNCONFIGURED FSTAB`，不是 fstab 把根指到 vdb。
7. 两盘 UUID/标签不同，不是同一文件系统的别名。

详见 `disk/root-vda-vs-vdb.txt`、`virt/dmesg-root-disk.txt`，以及 [`docs/boot-chain/BOOT-CHAIN-FULL.md`](docs/boot-chain/BOOT-CHAIN-FULL.md) 第 3、5 节。

## 3. 服务拉起链（高层）

采集时重新核对进程树：

```text
PID 1  /tini -- /pod-daemon ...
 └── PID 7  /pod-daemon
      ├── sand-exit-watch   (subreaper / lifecycle)
      │     └──（其下为 start-sand-box 在 exec 前 fork 出的各服务）
      └── cursor-agent-store-fuse
```

要点：

| 组件 | 角色 |
|------|------|
| **tini** (krallin/tini v0.19.0) | 仅作 PID 1：启动**一个**子进程、收尸、转发信号。不枚举业务服务。 |
| **pod-daemon** | Rust 沙箱守护进程（内部名 anyrun 相关）；提供 gRPC 等，由宿主机侧下发创建进程。 |
| **start-sand-box** | bash 编排脚本：fork 出 exec-daemon、桌面、egress、supervisor 等，再 **exec** 成 `sand-exit-watch`。 |
| **sand-exit-watch** | Python subreaper：盯 lifecycle owner；管理如 orbitd 的 daemon launcher；owner 退出则收尾退出 box。 |

因此：**全套 sand 服务不是 tini 拉起的**。容器内的编排入口是 `start-sand-box` → `sand-exit-watch`，而 `start-sand-box` 由 `pod-daemon` 拉起。tini 和 pod-daemon 本身由底座 isod 调用 runc 启动。

挂在 PID 1 下的 `dbus-daemon` / `dconf` / `bamf` 多半是桌面会话孤儿被 init 收养，不是 tini 主动启动。

二进制说明见 `binaries/binary-notes.txt`；进程分类见 `process/classification.md`。

## 4. 其他快照内容

- CPU / 内存：`cpuinfo-summary.txt`、`meminfo.txt`
- 磁盘与挂载：`disk/`、`mounts.txt`
- 网络（沙箱内网）：`network/`
- 软件包：约 665 个 `ii` 包名列表于 `packages/dpkg-ii-names.txt`
- 脱敏说明：`REDACTIONS.md`

## 5. 局限

- DMI 信息可能不可读；未依赖 `systemd-detect-virt`。
- 进程数与桌面/Chrome 实例会随会话变化。
- `pod-daemon` 为专有二进制，本快照只记录 file/sha256/路径线索，不包含反编译结果。
