# 在 Debian 12 上模拟「vda 底座 + vdb 根 + runc 切换」

> 实验步骤，用来对齐磁盘和 runc 边界。权威叙事是 [`../../BOOT-CHAIN-FULL.md`](../../BOOT-CHAIN-FULL.md)。在虚拟机或空闲机器上做，做完按文末清理。

目标：用 **一块 loop 盘模拟 vdb**、用 **当前系统模拟 vda（底座）**，经「准备 rootfs → mount 到 image/rootfs → runc run（pivot_root）」得到与 anyrun/isod **同构** 的效果。  
**不必**安装 isod/pod-daemon；服务可用 `sleep infinity` / `bash` 代替。

> 安全：在 **虚拟机或空闲机器** 上做；需要 root / `CAP_SYS_ADMIN`；不要把生产 token 写进 config；做完按文末清理。

## 角色映射

| 真实 anyrun | 本模拟 |
|-------------|--------|
| `/dev/vda` 底座 Debian 12 | 你的 Debian 12 宿主机根 |
| `/dev/vdb` 工作负载根 | `vdb.img` + `losetup` → `/dev/loopX` |
| isod（HydrateRootar / PrepareRootfs） | 你手动 `mkfs` + `debootstrap`/`rsync` + `mount` |
| runc | 同左 |
| tini + pod-daemon | `/bin/bash -c 'sleep infinity'` 或自备小入口 |

编号流程（与真实链路镜像）：

1. **底座已启动**（你的 Debian 12）  
2. **准备第二块盘**（sparse 文件 = vdb）并 mkfs.ext4  
3. **Hydrate**：把一个最小 rootfs 写入该盘（≈ HydrateRootar / populate_writable_block_device）  
4. **挂到** `/var/lib/demo-isod/containers/demo/image/rootfs`（≈ isod mount_block_device_rw）  
5. **写 OCI config + runc run -d**（≈ CreateContainer / StartContainer）  
6. **runc exec** 验证容器内 `/` 来自 loop 盘  
7. **清理**

---

## 0. 前置

```bash
sudo apt-get update
sudo apt-get install -y runc debootstrap util-linux e2fsprogs jq

# 确认
runc --version
id -u   # 后续命令用 sudo
```

建议工作目录：

```bash
export DEMO=/var/lib/demo-isod
sudo mkdir -p "$DEMO"/{images,containers/demo/bundle,containers/demo/image/rootfs,runc-state}
cd "$DEMO"
```

---

## 1. 创建「vdb」镜像并格式化

```bash
# 2G 稀疏文件足够最小 Debian；可改大
sudo dd if=/dev/zero of="$DEMO/images/vdb.img" bs=1M count=0 seek=2048
sudo mkfs.ext4 -L demo-vdb "$DEMO/images/vdb.img"

LOOP=$(sudo losetup --find --show "$DEMO/images/vdb.img")
echo "LOOP=$LOOP" | sudo tee "$DEMO/images/vdb.loop"
# 例：/dev/loop0
```

---

## 2. 写入 rootfs（模拟 HydrateRootar）

### 方案 A（推荐）：debootstrap 直接装到挂载点

```bash
LOOP=$(cat "$DEMO/images/vdb.loop")
ROOTFS="$DEMO/containers/demo/image/rootfs"

sudo mount "$LOOP" "$ROOTFS"
sudo debootstrap --variant=minbase bookworm "$ROOTFS" http://deb.debian.org/debian

# 容器里要有能跑的 PID1 替代物
sudo chroot "$ROOTFS" /bin/bash -c 'apt-get update && apt-get install -y --no-install-recommends bash coreutils util-linux procps'

# 埋一个标记，方便进容器后验证「这是 vdb」
echo 'demo-vdb-rootfs' | sudo tee "$ROOTFS/etc/demo-disk-id"
sudo umount "$ROOTFS"
```

### 方案 B：先 debootstrap 到目录再 rsync 进盘

```bash
sudo debootstrap --variant=minbase bookworm /tmp/demo-rootfs http://deb.debian.org/debian
LOOP=$(cat "$DEMO/images/vdb.loop")
sudo mount "$LOOP" "$DEMO/containers/demo/image/rootfs"
sudo rsync -aHAX /tmp/demo-rootfs/ "$DEMO/containers/demo/image/rootfs/"
echo 'demo-vdb-rootfs' | sudo tee "$DEMO/containers/demo/image/rootfs/etc/demo-disk-id"
sudo umount "$DEMO/containers/demo/image/rootfs"
```

> 真实 isod 可能是：下载 squashfs/erofs/ext4 →（可选 overlay）→ **populate 到块设备** → mount。  
> 这里用 debootstrap/rsync 代替下载与 populate，**最终形态相同**：块设备上有一份可 pivot 的根。

---

## 3. 再次挂载 rootfs（模拟 isod mount → image/rootfs）

```bash
LOOP=$(cat "$DEMO/images/vdb.loop")
ROOTFS="$DEMO/containers/demo/image/rootfs"
sudo mount "$LOOP" "$ROOTFS"
findmnt "$ROOTFS"
# 应显示 LOOP 设备，fstype ext4
```

---

## 4. 生成并编辑 OCI `config.json`

```bash
BUNDLE="$DEMO/containers/demo/bundle"
cd "$BUNDLE"
sudo runc spec
```

用下面脚本改成贴近真实环境的最小配置（网络用宿主机 netns；可按需改成新建 network）：

```bash
sudo python3 - <<'PY'
import json
from pathlib import Path
p = Path("/var/lib/demo-isod/containers/demo/bundle/config.json")
cfg = json.loads(p.read_text())

cfg["root"] = {
    "path": "/var/lib/demo-isod/containers/demo/image/rootfs",
    "readonly": False,
}
cfg["hostname"] = "demo-vdb-container"

cfg["process"]["terminal"] = False
cfg["process"]["user"] = {"uid": 0, "gid": 0}
cfg["process"]["args"] = ["/bin/bash", "-c", "sleep infinity"]
cfg["process"]["cwd"] = "/"
cfg["process"]["env"] = [
    "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
    "TERM=xterm",
]

# 命名空间：对齐现场 —— pid/ipc/uts/mount 新建；网络共享宿主
cfg["linux"]["namespaces"] = [
    {"type": "pid"},
    {"type": "ipc"},
    {"type": "uts"},
    {"type": "mount"},
    {"type": "network", "path": "/proc/1/ns/net"},
]

# 精简 mounts：对齐现场的 4 条（演示够用）
cfg["mounts"] = [
    {"destination": "/proc", "type": "proc", "source": "proc"},
    {"destination": "/dev", "type": "bind", "source": "/dev",
     "options": ["rbind", "rw", "rprivate"]},
    {"destination": "/dev/shm", "type": "tmpfs", "source": "shm",
     "options": ["nosuid", "noexec", "nodev", "mode=1777"]},
    {"destination": "/sys", "type": "bind", "source": "/sys",
     "options": ["rbind", "rw", "rprivate"]},
]

# 明确使用 pivot_root（默认 false 即启用 pivot）
cfg["linux"].pop("rootfsPropagation", None)
# 不要设置 linux.noPivotRoot；缺省即 pivot

p.write_text(json.dumps(cfg, indent=2))
print("wrote", p)
PY
```

对照真实 config 的差异（可忽略）：真实入口是 tini/pod-daemon、能力集极大、cgroup 名=pod-id；模拟已足够验证「根在另一块盘」。

---

## 5. 启动容器

```bash
BUNDLE="$DEMO/containers/demo/bundle"
ROOT="$DEMO/runc-state"

sudo runc --root "$ROOT" run -d --bundle "$BUNDLE" demo
sudo runc --root "$ROOT" list
sudo runc --root "$ROOT" state demo
```

---

## 6. 进入并验证「`/` 是 vdb」

```bash
ROOT="$DEMO/runc-state"

# 交互 shell
sudo runc --root "$ROOT" exec -t demo /bin/bash

# 或非交互检查
sudo runc --root "$ROOT" exec demo cat /etc/demo-disk-id
# 期望：demo-vdb-rootfs

sudo runc --root "$ROOT" exec demo findmnt /
# 期望：目标为之前的 loop 设备（在容器里可能显示为 /dev/loopX 或相同 maj:min）

sudo runc --root "$ROOT" exec demo cat /proc/1/cmdline | tr '\0' ' '; echo
# 期望含 sleep infinity
```

宿主机侧再确认：

```bash
findmnt /var/lib/demo-isod/containers/demo/image/rootfs
# 仍应挂着 loop；runc pivot 不拆宿主上的这次 mount
lsblk
```

---

## 7. 清理（务必按序）

```bash
ROOT="$DEMO/runc-state"
BUNDLE_ROOTFS="/var/lib/demo-isod/containers/demo/image/rootfs"

sudo runc --root "$ROOT" kill demo KILL 2>/dev/null || true
sudo runc --root "$ROOT" delete demo 2>/dev/null || true

sudo umount "$BUNDLE_ROOTFS" 2>/dev/null || sudo umount -l "$BUNDLE_ROOTFS"

LOOP=$(cat /var/lib/demo-isod/images/vdb.loop 2>/dev/null || true)
[ -n "$LOOP" ] && sudo losetup -d "$LOOP"

# 可选：删掉镜像与目录
# sudo rm -rf /var/lib/demo-isod
```

---

## 可选加强（更接近 isod）

1. **第二块「热插」盘**：在 KVM 里给 VM 加 virtio 盘，用真 `/dev/vdb` 替换 loop。  
2. **squashfs + overlay**：  
   `mksquashfs rootfs_dir image.squashfs` → `losetup` + `mount -t squashfs` → overlay upper 在另一目录 → 再把 merged 当作 root.path（对应 Hydrate V2/V3）。  
3. **整盘 EXT4 镜像文件**（更像 V5）：  
   对 `vdb.img` 直接 populate，然后 `mount -o loop` 或 `losetup` 挂到 rootfs 路径。  
4. **自备 tini**：把 `tini` 静态二进制放进 rootfs，`args` 改成 `["/tini","--","/bin/bash","-c","sleep infinity"]`。

---

## 安全注意

- `runc` + `pivot_root` + bind `/dev` ≈ 接近特权容器，**等同于 root 级隔离实验**，不要在共用生产机上跑。  
- 配置里不要放真实 `SAND_*` / token。  
- 清理时若 `umount` 失败，先 `runc delete`，再查 `mount | grep demo-isod`，必要时 `umount -l`。  
- `losetup -d` 前必须先 umount，否则 EBUSY。

---

## 一句话对照

**真实：** isod 把工作负载 hydrate/populate 到 **vdb**，挂到 `.../image/rootfs`，`runc` pivot 进去。  
**模拟：** 你把 debootstrap 写进 **loop 盘**，挂到同一布局，再 `runc run`。  
差异只在「谁下载/谁 gRPC」，**磁盘 + runc 边界一致**。
