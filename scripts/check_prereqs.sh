#!/usr/bin/env bash
# Vérifie les prérequis du TP dans WSL et sauvegarde la sortie comme preuve.
set -u
mkdir -p evidence
{
  echo "### WSL / OS";            uname -a; grep PRETTY_NAME /etc/os-release
  echo; echo "### Docker";        docker version --format 'Client {{.Client.Version}} / Server {{.Server.Version}}'
  echo; echo "### Docker sans sudo"; docker ps >/dev/null && echo "OK : accès au socket Docker"
  echo; echo "### Terraform";     terraform version
  echo; echo "### Git";           git --version
  echo; echo "### curl";          curl --version | head -1
} 2>&1 | tee evidence/A0_prereqs.txt
