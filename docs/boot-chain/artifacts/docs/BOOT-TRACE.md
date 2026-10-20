# 真实路径：从 vda（Firecracker 底座）到 vdb（sand-box 根）

> 早期现场重建。权威叙事是 [`../../BOOT-CHAIN-FULL.md`](../../BOOT-CHAIN-FULL.md)。文末文件路径已改成仓库内相对路径。`multi-user.target.wants` 的实测列表里没有 swap 单元；swap 脚本在磁盘上，cmdline 把 `SWAP_SIZE_MB` 设为 0。

本文基于现场证据重建：**内核 cmdline 仍 `root=/dev/vda`**，而容器内 **`/` = `/dev/vdb` ext4**。切换不是整机 `pivot_root` 换根，而是 **isod 准备 rootfs + runc 起容器（容器内 pivot_root）**。

## 角色对照

| 角色 | 设备/组件 | 现场 |
|------|-----------|------|
| 底座根（host） | `/dev/vda` | Debian 12 bookworm + systemd + isod/runc/tini/pod-daemon |
| 工作负载根（guest disk） | `/dev/vdb` | Debian 13 风格 sand-box；LABEL=`ext4-writer` |
| 编排器 | `isod` | `ExecStart=/usr/local/bin/isod --listen-addr 0.0.0.0:50052 --base-dir /var/lib/isod` |
| 运行时 | `runc 1.3.6` | bundle 在 `/var/lib/isod/containers/<pod>/bundle` |
| 容器入口 | tini + pod-daemon | `["/tini","--","/pod-daemon", ...]` |

磁盘：

- vda UUID `e6bda90c-4d45-4cd5-8585-21f19fae583d`，约 1.4G/126G，挂到调查点 `/mnt/vda`
- vdb UUID `00000000-0000-0000-0000-000000000004`，LABEL `ext4-writer`，约 7.2G/125G，即当前 `/`

## 逐步启动链路

### 1. Firecracker / anyrun 启动 VM

- 内核参数（现场 `/proc/cmdline`）：`root=/dev/vda rw`（出现两次）、`console=ttyS0`、`ip=172.30.0.2::...`、`systemd.unified_cgroup_hierarchy=1`、`nomodule` 等。
- 第一块 virtio 盘 **vda** 被挂为真实宿主机根。
- `/etc/anyrun/build-info`：`Firecracker rootfs / isod`，`commit=5a6eda56...`，`generation=141355`。

### 2. systemd 起来，拉起配套单元

`multi-user.target` 启用（节选）：

- **isod.service**（核心）
- eth0-routes.service（在 isod/docker 之前）
- docker / containerd / docker-socat（TCP 2375 暴露 docker.sock）
- nvidia-gpu.service。磁盘上有 `setup-swap.sh`，cmdline 设 `SWAP_SIZE_MB=0`；这份 `multi-user.target.wants` 列表里没有 swap 单元

**isod.service 原文要点：**

```
ExecStart=/usr/local/bin/isod --listen-addr 0.0.0.0:50052 --base-dir /var/lib/isod
KillMode=process
Delegate=yes
Environment=RUST_LOG=info
```

注释说明：重启 isod **不能 SIGKILL runc 监督进程**；下次启动会从 runc + 磁盘 + mountinfo **重新收养**容器。

底座工具链也在 vda 上：`/usr/local/bin/{isod,pod-daemon,tini,umoci,mkfs.erofs,fsck.erofs}`，`/usr/bin/runc`。

### 3. 控制面经 gRPC 调 isod（:50052）

二进制字符串暴露的 `anyrun.v1.IsodService` RPC 包括：

- `HydrateRootar` / `PrepareRootfs`
- `CreateContainer` / `StartContainer` / …
- `MountExtraDrives` / `RescanPciBus` / `ReleasePciBlockDevice`
- `PullImage` / `ImportImageArchive`（skopeo + umoci）等

**HydrateRootar（V1–V5 / LEGACY / V2_LAYERED）在做什么（由 isod 字符串推断）：**

| 模式 | 行为概要 |
|------|----------|
| V1 / legacy | 下载 rootar 归档并展开 |
| V2 / V3 | 下载 **squashfs** → `losetup` → `mount -t squashfs` → 常配合 **overlay2** |
| V2_LAYERED | 分层 overlay；写 `meta.json` |
| V4 | 格式 **SQUASHFS / EROFS / EXT4**；可 `unsquashfs` / `fsck.erofs` 或直接挂载；经 **nsenter** 挂载 |
| V5 | **强制 EXT4 镜像**；下载后 `mount -t ext4`（可见 `ro,noload`）；写 hydration metadata |

鉴权：`presigned_url` **或** `lease_token`（二选一）+ 可选 `blob_key`。

**MountExtraDrives：**

- `guest_device` 必须是 **`/dev/vdb` … `/dev/vdz`**（不能是根盘 vda）
- 流程含：`blkid` → 必要时 `mkfs.ext4 -F -q` → `mount`；可改 rw/ro

**与本机最吻合的块设备路径（CreateContainer + IsodBlockDevice）：**

isod 内有明确符号：

- `IsodBlockDevice`（`device_path` + `filesystem`）
- `mount_block_device_ro` / `mount_block_device_rw`
- `populate_writable_block_device`
- `flush_populated_writable_rootfs`
- 「fresh writable population requires **ext4**」「eager rootfs population source」

再结合：**容器 `/` 的后端就是 `/dev/vdb`**，且 LABEL=`ext4-writer`、UUID 呈人工占位形态 → 高度可信的故事是：

1. （可选）`RescanPciBus` 热插第二块盘 vdb  
2. `HydrateRootar` 把 rootar 内容落到可挂载源（squashfs/erofs/ext4 文件或图层）  
3. `CreateContainer`/`PrepareRootfs` 用 **IsodBlockDevice=/dev/vdb**：**populate** 可写 ext4 到 vdb，再 **mount rw** 到  
   `/var/lib/isod/containers/<pod>/image/rootfs`  
4. 或 V5 直接把 EXT4 镜像 hydrate 到挂载点 / 块设备  

> **缺口：** 磁盘上 **没有留下** `meta.json` / `rootar_v*` / hydration metadata 文件（可能写在仅底座可见的路径、tmpfs，或用完即删）。因此 **无法 100% 钉死是 V4/V5 还是 block-populate**；只能说「最终 rootfs 挂载点 + 后端块设备 = vdb」证据充分。

### 4. 写出 OCI bundle 并 runc 启动

目录布局（vda 残留）：

```
/var/lib/isod/containers/<pod>/
  bundle/config.json          # OCI runtime spec
  image/rootfs/               # 挂载点（二次挂 vda 时看到是空的）
/var/lib/isod/runc-state/<pod>/state.json
```

**root.path**（绝对路径）：

`/var/lib/isod/containers/pod-nzlapxyzlvdmnjzu6uf6mcaaly-02fe127a/image/rootfs`

**process.args：**

```json
["/tini", "--", "/pod-daemon",
 "--ssh-auth-sock-path", "/run/host-services/ssh-auth.sock",
 "--ssh-auth-vsock-port", "52"]
```

**namespaces：** pid / ipc / uts / mount 新建；**network 加入底座 `/proc/1/ns/net`**。

**mounts：** 仅 `/proc`、`/dev`（rbind 宿主机）、`/dev/shm`、`/sys`。  
（容器内能 `lsblk` 到 vda/vdb，正是因为 bind 了整个 `/dev`。）

**no_pivot_root: false** → runc 在容器 mount ns 里对 `image/rootfs` 做 **pivot_root**，于是容器里的 `/` 就是已挂好的 **vdb 文件系统**。

等价宿主机操作（概念上，非精确 argv）：

```bash
# isod 内部大致如此
mount /dev/vdb /var/lib/isod/containers/<pod>/image/rootfs   # 或先 populate 再 mount
runc --root /var/lib/isod/runc-state run -d --bundle ... <pod>
```

### 5. 容器内视角（你现在所在处）

- PID1：`/tini -- /pod-daemon ...`
- cgroup：`.../system.slice/pod-nzlapxyzlvdmnjzu6uf6mcaaly-02fe127a`（agent 子 cgroup 另有 `/agent`）
- `findmnt /` → `/dev/vdb`
- 底座仍在：**systemd + isod** 跑在 vda 上；只是你进不了那个 mount/pid ns（除非从宿主 nsenter）

## 架构简图

```
┌─ Firecracker VM ─────────────────────────────────────────┐
│  cmdline: root=/dev/vda                                   │
│  ┌─ 底座 (Debian 12 / systemd) ─ /dev/vda ─────────────┐ │
│  │  isod :50052                                          │ │
│  │    ├─ HydrateRootar / PrepareRootfs                   │ │
│  │    ├─ (可选) MountExtraDrives / PCI rescan → vdb      │ │
│  │    ├─ populate/mount /dev/vdb → .../image/rootfs      │ │
│  │    └─ runc run (pivot_root)                           │ │
│  │         │                                             │ │
│  │         ▼                                             │ │
│  │  ┌─ 容器 ─ / 实际是 /dev/vdb (Debian 13 sand-box) ─┐ │ │
│  │  │  tini → pod-daemon                               │ │ │
│  │  │  共享 netns；bind /dev /sys                      │ │ │
│  │  └──────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────┘
```

## 脱敏配置与摘要文件

- OCI（几乎所有 `SAND_*` 都写成 `REDACTED`）：[`runc-config.sanitized.json`](runc-config.sanitized.json)
- 只涂凭据、保留其余现场环境变量的原文：[`../vda-isod-state/config.redacted.json`](../vda-isod-state/config.redacted.json)、[`../vda-isod-state/state.redacted.json`](../vda-isod-state/state.redacted.json)
- state 摘要：[`runc-state.summary.md`](runc-state.summary.md)
- 可复现的磁盘 + runc 模拟：[`SIMULATE-DEBIAN12.md`](SIMULATE-DEBIAN12.md)
