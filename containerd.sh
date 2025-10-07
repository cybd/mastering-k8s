#!/bin/bash

# Exit on error
set -e

HOST_IP=$(hostname -I | awk '{print $1}')

echo "Starting containerd..."
export PATH=$PATH:/opt/cni/bin:kubebuilder/bin
sudo PATH=$PATH:/opt/cni/bin:/usr/sbin /opt/cni/bin/containerd -c /etc/containerd/config.toml &