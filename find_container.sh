#!/usr/bin/env bash
if [ -z "$1" ]; then
  echo "Uso: $0 <PID>"
  exit 1
fi

PID=$1
CID=$(grep -oE '[0-9a-f]{64}' /proc/$PID/cgroup | head -n1)
docker ps --no-trunc | grep $CID | awk '{print $1}'
