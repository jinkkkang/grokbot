# 系统分析摘要（中文）

采集时间见 `CAPTURED_AT.txt`。以下结论均基于本目录内的只读证据，并在采集时重新核对。

## 1. 环境定性

- **KVM 虚拟机客户机**（非裸机、非典型 Docker/Podman 容器）。
- 证据：`/proc/cmdline` 含 `clocksource=kvm-clock`、`root=/dev/vda`、`console=ttyS0`；CPU 有 `hypervisor`；磁盘为 virtio（`vda`/`vdb`）；无 `/.dockerenv` / `/run/.containerenv`。
- 主机名形如 `grok-bot-vm-*`；PID 1 为 `tini`，子进程为 `/pod-daemon`（沙箱运行时，而非 systemd）。

## 2. 为何 cmdline 写 root=/dev/vda，而 df 显示 vdb？

**不是**内核把设备改名，而是「先挂 vda，再用户态切根到 vdb」。

1. 内核按 cmdline 把 **`/dev/vda`** 挂为初始根（dmesg：`VFS: Mounted root ... on device 254:0`，即 vda）。
2. 随后 **`/dev/vdb`** 被挂上（dmesg 中有 `EXT4-fs (vdb): mounted ...`）。
3. 用户态做根切换（`pivot_root` / 同类操作）后，**当前** `/` 来自 vdb；`findmnt /`、`df`、`stat /` 均指向 vdb。
4. `/proc/cmdline` 是启动参数快照，**不会**随后改写，故仍显示 `root=/dev/vda`。
5. `/proc/fs/ext4/` 下同时可见 `vda` 与 `vdb`，说明 vda 的 ext4 仍可能被内核挂着，但已不在可见挂载树中作为 `/`（典型 pivot 残留）。
6. `/etc/fstab` 为 `UNCONFIGURED FSTAB`，不是 fstab 把根指到 vdb。
7. 两盘 UUID/标签不同，不是同一文件系统的别名。

详见 `disk/root-vda-vs-vdb.txt`、`virt/dmesg-root-disk.txt`。

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

因此：**全套服务不是 tini 拉起的**；真正编排入口是 `start-sand-box` → `sand-exit-watch`，而 `start-sand-box` 由 `pod-daemon`/宿主机 CreateProcess 路径拉起。

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
