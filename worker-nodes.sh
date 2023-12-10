#!/bin/bash
#
# All serwers (Worker Nodes)

set -euxo pipefail

KUBERNETES_VERSION="1.28.4-1.1"

sudo swapoff -a

sudo apt-get update -y
sudo apt-get install -y cron

(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true

cat <<EOF | sudo tee /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

# CRI CRI-O (https://github.com/cri-o/cri-o)

sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates software-properties-common curl gpg

sudo curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/cri-o.list

sudo apt-get update -y
sudo apt-get install -y cri-o
sudo apt-mark hold cri-o

sudo systemctl daemon-reload
sudo systemctl enable --now crio.service

# OCI crun (https://github.com/containers/crun)

sudo apt-get update -y
sudo apt-get install -y crun

# Kubernetes (https://github.com/kubernetes/kubernetes)

sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo apt-get install -y kubelet=$KUBERNETES_VERSION kubeadm=$KUBERNETES_VERSION kubectl=$KUBERNETES_VERSION
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl daemon-reload
sudo systemctl enable --now kubelet.service

sudo apt-get update -y
sudo apt-get install -y jq

local_ip="$(ip --json addr show eth0 | jq -r '.[0].addr_info[] | select(.family == "inet") | .local')"
cat > /etc/default/kubelet << EOF
KUBELET_EXTRA_ARGS=--node-ip=$local_ip
EOF
