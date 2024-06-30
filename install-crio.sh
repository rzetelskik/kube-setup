#!/bin/bash
set -euExo pipefail
shopt -s inherit_errexit

KUBERNETES_VERSION="${KUBERNETES_VERSION=v1.30.2}"
export KUBERNETES_VERSION

# Raise crio limits
mkdir -p /etc/systemd/system/cri-o.service.d
cat << EOF | tee /etc/systemd/system/cri-o.service.d/override.conf
[Service]
LimitNOFILE=10485760
LimitNPROC=10485760
EOF

#source /etc/os-release
KUBERNETES_VERSION_SHORT=$( echo "${KUBERNETES_VERSION}" | cut -d'.' -f1-2 )
export KUBERNETES_VERSION_SHORT
KUBERNETES_PKG_VERSION=${KUBERNETES_VERSION##v}-1.1
export KUBERNETES_PKG_VERSION

apt-get update
apt-get install -y software-properties-common apt-transport-https ca-certificates curl gpg

mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION_SHORT}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION_SHORT}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/stable:/${KUBERNETES_VERSION_SHORT}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/${KUBERNETES_VERSION_SHORT}/deb/ /" | tee /etc/apt/sources.list.d/cri-o.list

apt-get update
apt-get install -y --no-install-recommends cri-o="${KUBERNETES_PKG_VERSION}"

cat << EOF | tee /etc/crio/crio.conf.d/02-cgroup-manager.conf
[crio.runtime]
conmon_cgroup = "pod"
cgroup_manager = "systemd"
EOF

systemctl daemon-reload
systemctl enable --now crio
