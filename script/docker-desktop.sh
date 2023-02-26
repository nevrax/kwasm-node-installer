#!/usr/bin/env sh
set -euo pipefail

# Copy assets to docker rootfs
cp -r /assets /$NODE_ROOT/opt/kwasm

# Prevent restart loop, only on firstrun
CRI_DOCKERD_TARGET_SHA256=$(nsenter -m/$NODE_ROOT/proc/1/ns/mnt -- sha256sum /var/lib/kube-binary-cache-debian/cri-dockerd |  awk '{print $1}')
CRI_DOCKERD_SOURCE_SHA256=$(sha256sum /assets/cri-dockerd | awk '{print $1}')
if [ $CRI_DOCKERD_TARGET_SHA256 != $CRI_DOCKERD_SOURCE_SHA256 ]; then
    # Replace cri-dockerd
    nsenter -m/$NODE_ROOT/proc/1/ns/mnt -- sh -c "cp /containers/services/docker/rootfs/opt/kwasm/cri-dockerd /var/lib/kube-binary-cache-debian/cri-dockerd"
    # Place shims in containerd path
    CONTAINERD_PID=$(ps aux | grep "containerd$" | awk '{print $1}')
    nsenter -m/$NODE_ROOT/proc/$CONTAINERD_PID/ns/mnt -- sh -c "
    mount / -o remount,rw
    cp /containers/services/docker/rootfs/opt/kwasm/containerd-shim-* /usr/bin/
    mount / -o remount,ro"
    # Restart Docker Desktop 
    /assets/curl --unix-socket /mnt/node-root/run/guest-services/lifecycle-server.sock localhost/vm/shutdown -XPOST
fi

# Not persistent change, needs to be run after every restart
CONTAINERD_PID=$(ps aux | grep "containerd.toml$" | head -n 1 | awk '{print $1}')
nsenter -m/$NODE_ROOT/proc/$CONTAINERD_PID/ns/mnt -- sh -c "cp -f /opt/kwasm/containerd-shim-* /usr/local/bin/"
