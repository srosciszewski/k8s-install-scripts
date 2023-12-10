#!/bin/bash
#
# Control Plane (Master Nodes)

set -euxo pipefail

KUBERNETES_VERSION="v1.28.4"

PUBLIC_IP_ACCESS="false"
NODENAME=$(hostname -s)
POD_CIDR="10.10.0.0/16"

sudo kubeadm config images pull --kubernetes-version="$KUBERNETES_VERSION"

if [[ "$PUBLIC_IP_ACCESS" == "false" ]]; then

    MASTER_PRIVATE_IP=$(ip addr show eth0 | awk '/inet / {print $2}' | cut -d/ -f1)
    sudo kubeadm init --apiserver-advertise-address="$MASTER_PRIVATE_IP" --apiserver-cert-extra-sans="$MASTER_PRIVATE_IP" --pod-network-cidr="$POD_CIDR" --node-name="$NODENAME" --ignore-preflight-errors Swap --kubernetes-version="$KUBERNETES_VERSION"

elif [[ "$PUBLIC_IP_ACCESS" == "true" ]]; then

    MASTER_PUBLIC_IP=$(curl ifconfig.me && echo "")
    sudo kubeadm init --control-plane-endpoint="$MASTER_PUBLIC_IP" --apiserver-cert-extra-sans="$MASTER_PUBLIC_IP" --pod-network-cidr="$POD_CIDR" --node-name="$NODENAME" --ignore-preflight-errors Swap --kubernetes-version="$KUBERNETES_VERSION"

else
    echo "Error: MASTER_PUBLIC_IP has an invalid value: $PUBLIC_IP_ACCESS"
    exit 1
fi

mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

# CNI Calico (https://github.com/projectcalico/calico)

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.4/manifests/tigera-operator.yaml
curl https://raw.githubusercontent.com/projectcalico/calico/v3.26.4/manifests/custom-resources.yaml -O

sed -i "s/cidr: 192\.168\.0\.0\/16/cidr: 10.10.0.0\/16/g" custom-resources.yaml

kubectl create -f custom-resources.yaml

# CNI flannel (https://github.com/flannel-io/flannel)

#kubectl create -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

kubectl taint nodes --all node-role.kubernetes.io/control-plane-
