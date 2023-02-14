#!/usr/bin/env sh
set -euo pipefail

# Prevent restart loop, only on firstrun
if [ ! -d /$NODE_ROOT/opt/kwasm ]; then
    # Copy assets to docker rootfs
    cp -r /assets /$NODE_ROOT/opt/kwasm
    # Replace cri-dockerd
    nsenter -m/$NODE_ROOT/proc/1/ns/mnt -- sh -c "cp /containers/services/docker/rootfs/opt/kwasm/cri-dockerd /var/lib/kube-binary-cache-debian/cri-dockerd"
    # Place shims in containerd path
    CONTAINERD_PID=$(ps aux | grep "containerd.toml$" | head -n 1 | awk '{print $1}')
    nsenter -m/$NODE_ROOT/proc/$CONTAINERD_PID/ns/mnt -- sh -c "cp /opt/kwasm/containerd-shim-* /usr/local/bin/"
    # Restart Docker Desktop 
    /assets/curl --unix-socket /mnt/node-root/run/guest-services/lifecycle-server.sock localhost/vm/shutdown -XPOST
fi

# Not persistent change, needs to be run after every restart
CONTAINERD_PID=$(ps aux | grep "containerd$" | awk '{print $1}')
nsenter -m/$NODE_ROOT/proc/$CONTAINERD_PID/ns/mnt -- sh -c "
mount / -o remount,rw
cp /containers/services/docker/rootfs/opt/kwasm/containerd-shim-* /usr/bin/
mount / -o remount,ro"