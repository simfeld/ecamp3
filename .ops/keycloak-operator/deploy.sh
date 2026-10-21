#!/bin/sh

set -ea

SCRIPT_DIR=$(realpath "$(dirname "$0")")
cd "$SCRIPT_DIR"

action=${1:-diff}

if [ "$action" = "deploy" ]; then
  kubectl create namespace keycloak-operator --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -k "$SCRIPT_DIR"
  exit 0
fi

if [ "$action" = "diff" ]; then
  kubectl diff -k "$SCRIPT_DIR"
  exit 0
fi
