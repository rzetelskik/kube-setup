#!/bin/bash

set -euExo pipefail
shopt -s inherit_errexit

SCRIPTPATH="$( cd -- "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 ; pwd -P )"

# Github Action workers have DROP on FORWARD policy by default, Kube requires packet forwarding
iptables -w -P FORWARD ACCEPT

# Required by kubeadm
modprobe overlay
modprobe br_netfilter
swapoff -a
echo 'net.ipv4.ip_forward = 1' | tee -a  /etc/sysctl.d/90-kube.conf >/dev/null
# We need to raise `fs.nr_open` as it limits how high can systemd units configure LimitNOFILE
echo 'fs.nr_open = 10485760' | tee -a /etc/sysctl.d/90-kube.conf >/dev/null
echo 'fs.aio-max-nr = 10485760' | tee -a /etc/sysctl.d/90-kube.conf >/dev/null
echo 'net.bridge.bridge-nf-call-iptables  = 1' | tee -a /etc/sysctl.d/90-kube.conf >/dev/null
echo 'net.bridge.bridge-nf-call-ip6tables = 1' | tee -a /etc/sysctl.d/90-kube.conf >/dev/null

sysctl --system

systemctl daemon-reload
systemctl enable --now crio

rm /etc/ssl/certs/audit-policy.yaml || true
ln -s "${SCRIPTPATH}"/manifests/auditpolicy.yaml /etc/ssl/certs/audit-policy.yaml

rm /root/kubeadm-config.yaml || true
ln -s "${SCRIPTPATH}"/manifests/kubeadm-config.yaml /root/kubeadm-config.yaml

kubeadm init --config=/root/kubeadm-config.yaml --skip-phases=addon/kube-proxy

mkdir -p "${HOME}/.kube"
cat /etc/kubernetes/admin.conf > "${HOME}/.kube/config"
chown $( id -u ):$( id -g ) "${HOME}/.kube/config"

kubectl version

kubectl taint nodes --selector node-role.kubernetes.io/control-plane= --overwrite node-role.kubernetes.io/control-plane:NoSchedule
kubectl taint nodes --selector node-role.kubernetes.io/control-plane= node-role.kubernetes.io/control-plane-
kubectl taint nodes --selector node-role.kubernetes.io/control-plane= --overwrite node-role.kubernetes.io/master:NoSchedule
kubectl taint nodes --selector node-role.kubernetes.io/control-plane= node-role.kubernetes.io/master-

cilium install --version 1.15.6 --set bpf.lbExternalClusterIP=true
cilium status --wait

kubectl -n kube-system rollout status --timeout=5m deployment.apps/coredns
