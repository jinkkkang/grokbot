# runc state.json 摘要

> 字段说明。脱敏全文在 [`../vda-isod-state/state.redacted.json`](../vda-isod-state/state.redacted.json)。权威叙事是 [`../../BOOT-CHAIN-FULL.md`](../../BOOT-CHAIN-FULL.md)。

来源：`/mnt/vda/var/lib/isod/runc-state/pod-nzlapxyzlvdmnjzu6uf6mcaaly-02fe127a/state.json`

（时间戳原为 UTC，下文已换算为 Asia/Shanghai）

## 基本信息

| 字段 | 值 |
|------|-----|
| id | `pod-nzlapxyzlvdmnjzu6uf6mcaaly-02fe127a` |
| init_process_pid | `1317`（底座宿主机 PID，非容器内 PID1） |
| created | 2026-10-18 16:10:57 Asia/Shanghai（原 `2026-10-18T08:10:57.695Z`） |
| rootless | `false` |
| no_pivot_root | `false`（使用 pivot_root） |
| OCI / runc | state `version` 1.2.1；底座二进制 `runc 1.3.6` |
| hostname | `grok-bot-vm-477963022` |
| rootfs | `/var/lib/isod/containers/pod-nzlapxyzlvdmnjzu6uf6mcaaly-02fe127a/image/rootfs` |
| labels | `bundle=/var/lib/isod/containers/pod-.../bundle` |

## Namespaces

配置侧（新建 + 共享网络）：

- NEWPID（新建）
- NEWIPC（新建）
- NEWUTS（新建）
- NEWNS / mount（新建）
- NEWNET → **`/proc/1/ns/net`**（与底座 systemd PID1 共享网络命名空间）

state 记录的 namespace_paths（指向 init pid 1317）：

- NEWCGROUP / NEWIPC / NEWNET / NEWNS / NEWPID / NEWTIME / NEWUSER / NEWUTS → `/proc/1317/ns/...`

## Cgroup

- 路径：`/sys/fs/cgroup/system.slice/pod-nzlapxyzlvdmnjzu6uf6mcaaly-02fe127a`
- cgroup 名与 pod id 一致

## Mounts（容器内，共 4 条）

| destination | source | type | 备注 |
|-------------|--------|------|------|
| `/proc` | `proc` | proc | |
| `/dev` | `/dev` | bind rbind,rw,rprivate | **整盘绑定宿主机 /dev**（故容器内可见 vda/vdb） |
| `/dev/shm` | `shm` | tmpfs mode=1777 | |
| `/sys` | `/sys` | bind rbind,rw,rprivate | |

无额外 workspace / 密钥 bind（OCI config 亦如此）。

## Capabilities

Bounding/Effective/Inheritable/Permitted/Ambient 各约 41 项，接近特权容器（含 CAP_SYS_ADMIN 等）。`resources.devices` 允许所有设备 `a:rwm`。

## 与现场对照

- 容器视角：`findmnt /` → `/dev/vdb` ext4；PID1 = `/tini -- /pod-daemon ...`
- 二次挂载的 vda 上 `image/rootfs/` **为空目录**：说明运行时是把 **vdb 挂到该挂载点**，挂载只存在于底座 mount namespace；从容器里 remount vda 看不到那次挂载。
