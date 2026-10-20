#!/bin/sh
# Boot-time NVIDIA GPU init for microVM guests.
#
# This ships in the *shared* rootfs, which runs on the vast majority of VMs that
# have no GPU, so it must be a clean no-op there: it bails immediately unless an
# NVIDIA GPU (PCI vendor 0x10de) is passed through. On GPU VMs it loads the kernel
# modules and creates the /dev/nvidia* device nodes -- the job nvidia-modprobe
# does on a normal install -- so the guest needs no NVIDIA userspace at all
# (userspace libs are injected into the workload container, not the guest).
#
# Intentionally never fails the boot: any problem just leaves the GPU
# unconfigured and logs to the journal.

# Bail unless an NVIDIA GPU is on the PCI bus.
gpu_present=
for vendor in /sys/bus/pci/devices/*/vendor; do
  [ -r "$vendor" ] || continue
  if [ "$(cat "$vendor")" = "0x10de" ]; then
    gpu_present=1
    break
  fi
done
if [ -z "$gpu_present" ]; then
  exit 0
fi

# Load the modules. nvidia-uvm depends on nvidia, so modprobe pulls it in; with
# the guest kernel's `nomodule` dropped only for passthrough VMs, this succeeds
# only where it should.
if ! modprobe nvidia; then
  echo "nvidia-gpu-setup: modprobe nvidia failed (modules missing or loading disabled); skipping" >&2
  exit 0
fi
if ! modprobe nvidia-uvm; then
  echo "nvidia-gpu-setup: modprobe nvidia-uvm failed; skipping device setup" >&2
  exit 0
fi

# Create device nodes from the kernel-assigned majors. NVIDIA reports each GPU's
# assigned minor in procfs; PCI enumeration order is not guaranteed to match it.
nvidia_major=$(awk '$2 == "nvidia-frontend" || $2 == "nvidia" { print $1; exit }' /proc/devices)
uvm_major=$(awk '$2 == "nvidia-uvm" { print $1; exit }' /proc/devices)
if [ -z "$nvidia_major" ] || [ -z "$uvm_major" ]; then
  echo "nvidia-gpu-setup: NVIDIA device majors are unavailable; skipping device setup" >&2
  exit 0
fi

ensure_node() {
  path=$1
  major=$2
  minor=$3
  if [ ! -e "$path" ] && ! mknod "$path" c "$major" "$minor"; then
    echo "nvidia-gpu-setup: failed to create $path" >&2
    return 1
  fi
  chmod 0666 "$path"
}

gpu_count=0
for information in /proc/driver/nvidia/gpus/*/information; do
  [ -r "$information" ] || continue
  minor=$(awk -F: '$1 ~ /^[[:space:]]*Device Minor[[:space:]]*$/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' "$information")
  case "$minor" in
  "" | *[!0-9]*)
    echo "nvidia-gpu-setup: invalid Device Minor in $information; skipping GPU" >&2
    continue
    ;;
  esac
  if ensure_node "/dev/nvidia${minor}" "$nvidia_major" "$minor"; then
    gpu_count=$((gpu_count + 1))
  fi
done

if [ "$gpu_count" -eq 0 ]; then
  echo "nvidia-gpu-setup: no initialized NVIDIA GPU minors found; skipping device setup" >&2
  exit 0
fi

if ! ensure_node /dev/nvidia-uvm "$uvm_major" 0 ||
  ! ensure_node /dev/nvidia-uvm-tools "$uvm_major" 1 ||
  ! ensure_node /dev/nvidiactl "$nvidia_major" 255; then
  exit 0
fi

echo "nvidia-gpu-setup: loaded modules and created device nodes for ${gpu_count} GPU(s)"
exit 0
