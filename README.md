# grokbot-sysinfo / Grok Bot 沙箱系统快照

This repository (`grokbot`) holds the snapshot at the repository root.

## What this is / 这是什么

**EN:** A sanitized, read-only snapshot of the Grok Bot sandbox VM (Debian 13 / trixie) used as the agent execution environment. Collected for documentation and later git push. Not a full disk image.

**中文:** 这是 Grok Bot 沙箱虚拟机（Debian 13 / trixie）的脱敏只读快照，用于记录运行环境并便于后续提交到 GitHub。不是整盘镜像。

## When captured / 采集时间

Captured: 2026-10-18 18:35:26 CST (Asia/Shanghai)

Hostname: `grok-bot-vm-477963022`
Kernel: `Linux grok-bot-vm-477963022 6.12.94+ #1 SMP PREEMPT_DYNAMIC Fri Oct 16 00:53:04 UTC 2026 x86_64 GNU/Linux`

## Caveats / 注意事项

1. **Sanitized** — process environments, tokens, keys, cookies, and grant files were not dumped. See `REDACTIONS.md`.
2. **Point-in-time** — process list and listen ports change when desktops/browsers start or stop.
3. **Not a Docker container** — evidence points to a KVM guest with a `tini` + `pod-daemon` sandbox runtime (see `SUMMARY.md` / `virt/`).
4. **`/proc/cmdline` vs `df`** — cmdline still says `root=/dev/vda`; live root is `/dev/vdb` after a userland root switch. Explained in `SUMMARY.md`.
5. Some tools (`blkid`) may be missing from PATH; UUID info then comes from `lsblk`.

## Layout / 目录结构

| Path | Content |
|------|---------|
| `cmdline.txt` | `/proc/cmdline` |
| `uname.txt`, `os-release.txt`, `hostname.txt`, `machine-id.txt` | Identity |
| `cpuinfo-summary.txt`, `meminfo.txt` | CPU / memory |
| `disk/` | lsblk, df, partitions, findmnt, root vda vs vdb |
| `mounts.txt` | `/proc/mounts` |
| `network/` | ip addr/route, ss -lntp |
| `process/` | ps, pstree, pid1, classification, boot-chain verify |
| `virt/` | virtio/KVM clues, dmesg excerpts |
| `packages/` | dpkg inventory + key packages |
| `binaries/` | file/sha256/version notes for tini, pod-daemon, scripts |
| `etc/` | non-secret configs (hosts, resolv, os-release, fstab) |
| `env-sanitized.txt` | Safe env keys only |
| `SUMMARY.md` | Chinese analysis summary |
| `REDACTIONS.md` | What was stripped |

## License / 许可

Snapshot data is factual system output. Upstream binaries (e.g. tini) retain their own licenses (MIT for tini).
