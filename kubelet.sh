#!/bin/bash

# Exit on error
set -e

HOST_IP=$(hostname -I | awk '{print $1}')

echo "Starting kubelet..."
sudo PATH=$PATH:/opt/cni/bin:/usr/sbin kubebuilder/bin/kubelet \
    --kubeconfig=/var/lib/kubelet/kubeconfig \
    --config=/var/lib/kubelet/config.yaml \
    --root-dir=/var/lib/kubelet \
    --cert-dir=/var/lib/kubelet/pki \
    --tls-cert-file=/var/lib/kubelet/pki/kubelet.crt \
    --tls-private-key-file=/var/lib/kubelet/pki/kubelet.key \
    --hostname-override=$(hostname) \
    --pod-infra-container-image=registry.k8s.io/pause:3.10 \
    --node-ip=$HOST_IP \
    --cloud-provider=external \
    --cgroup-driver=cgroupfs \
    --max-pods=50  \
    --v=1 &