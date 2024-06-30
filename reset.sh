#!/bin/bash

set -euExo pipefail
shopt -s inherit_errexit

sudo kubeadm reset --force --cri-socket=unix:///var/run/crio/crio.sock
