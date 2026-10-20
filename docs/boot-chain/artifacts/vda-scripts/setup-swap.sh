#!/bin/bash
set -e

# Configuration - can be overridden via kernel cmdline or environment
SWAP_FILE="${SWAP_FILE:-/var/swapfile}"
SWAP_SIZE_MB="${SWAP_SIZE_MB:-4096}"
# Swappiness: 0-200 (higher = more aggressive swapping)
#   0-10:  Avoid swap, only use when critical (good for SSDs with lots of RAM)
#   60:    Default Linux balance
#   100:   Treat RAM and swap equally (aggressive)
#   200:   Prefer swap over dropping caches (very aggressive, Linux 5.8+)
SWAPPINESS="${SWAPPINESS:-0}"

# Parse configuration from kernel cmdline if set via systemd.setenv
if [ -f /proc/cmdline ]; then
    CMDLINE_SWAP=$(grep -oP 'SWAP_SIZE_MB=\K[0-9]+' /proc/cmdline 2>/dev/null || true)
    if [ -n "$CMDLINE_SWAP" ]; then
        SWAP_SIZE_MB="$CMDLINE_SWAP"
    fi
    CMDLINE_SWAPPINESS=$(grep -oP 'SWAPPINESS=\K[0-9]+' /proc/cmdline 2>/dev/null || true)
    if [ -n "$CMDLINE_SWAPPINESS" ]; then
        SWAPPINESS="$CMDLINE_SWAPPINESS"
    fi
fi

# Handle swap disabled case (SWAP_SIZE_MB=0)
if [ "$SWAP_SIZE_MB" = "0" ]; then
    echo "Swap disabled (SWAP_SIZE_MB=0)"
    # Disable any existing swap
    swapoff -a 2>/dev/null || true
    rm -f "$SWAP_FILE" 2>/dev/null || true
    echo "Swap setup complete (disabled):"
    free -h
    exit 0
fi

echo "Setting up swap: file=$SWAP_FILE, size=${SWAP_SIZE_MB}MB, swappiness=$SWAPPINESS"

# Create swap file if it doesn't exist or has wrong size
NEED_CREATE=false
if [ ! -f "$SWAP_FILE" ]; then
    NEED_CREATE=true
else
    # Check if existing swap file has the correct size
    CURRENT_SIZE_BYTES=$(stat -c%s "$SWAP_FILE" 2>/dev/null || echo 0)
    DESIRED_SIZE_BYTES=$((SWAP_SIZE_MB * 1024 * 1024))
    if [ "$CURRENT_SIZE_BYTES" != "$DESIRED_SIZE_BYTES" ]; then
        echo "Swap file size mismatch: current=${CURRENT_SIZE_BYTES} bytes, desired=${DESIRED_SIZE_BYTES} bytes"
        swapoff "$SWAP_FILE" 2>/dev/null || true
        rm -f "$SWAP_FILE"
        NEED_CREATE=true
    fi
fi

if [ "$NEED_CREATE" = "true" ]; then
    echo "Creating ${SWAP_SIZE_MB}MB swap file..."
    # Use fallocate for speed, fall back to dd
    if ! fallocate -l "${SWAP_SIZE_MB}M" "$SWAP_FILE" 2>/dev/null; then
        dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$SWAP_SIZE_MB" status=progress
    fi
    chmod 600 "$SWAP_FILE"
    mkswap "$SWAP_FILE"
    echo "Swap file created successfully"
fi

# Enable swap
if ! swapon "$SWAP_FILE" 2>/dev/null; then
    echo "Swap file may already be active or needs reformatting"
    mkswap "$SWAP_FILE"
    swapon "$SWAP_FILE"
fi

# Configure swappiness
sysctl -w vm.swappiness="$SWAPPINESS"

# Enable memory overcommit to allow allocations beyond physical RAM
# This is essential for swap to work as expected - without this, the kernel
# may reject large allocations even when swap space is available
# 0 = heuristic (default, may reject), 1 = always allow, 2 = strict accounting
sysctl -w vm.overcommit_memory=1

# Enable ZSWAP for in-memory compression (if available)
if [ -f /sys/module/zswap/parameters/enabled ]; then
    echo Y > /sys/module/zswap/parameters/enabled
    echo "ZSWAP enabled"
fi

# Log final swap status
echo "Swap setup complete:"
swapon --show
free -h
