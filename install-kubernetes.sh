#!/bin/bash

set -euExo pipefail
shopt -s inherit_errexit

KUBERNETES_VERSION="${KUBERNETES_VERSION=v1.30.2}"
export KUBERNETES_VERSION

KUBERNETES_VERSION_SHORT=$( echo "${KUBERNETES_VERSION}" | cut -d'.' -f1-2 )
export KUBERNETES_VERSION_SHORT
KUBERNETES_PKG_VERSION=${KUBERNETES_VERSION##v}-1.1
export KUBERNETES_PKG_VERSION

apt-get update
apt-get install -y --no-install-recommends conntrack socat ebtables apt-transport-https ca-certificates curl gpg

mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION_SHORT}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_VERSION_SHORT}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update

# Remove conflicting packages (also removes podman).
apt-get remove containernetworking-plugins

apt-get remove kubelet kubeadm kubectl
apt-get autoremove
apt-get install -y --no-install-recommends kubelet="${KUBERNETES_PKG_VERSION}" kubeadm="${KUBERNETES_PKG_VERSION}" kubectl="${KUBERNETES_PKG_VERSION}"

# Podman got wiped by removing `containernetworking-plugins` so we have to install it from the new repo.
apt-get install -y --no-install-recommends podman
