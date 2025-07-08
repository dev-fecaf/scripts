CID=$(grep -oE -e '[0-9a-f]{64}' /proc/$1/cgroup | head -n1)
docker ps -f id=$CID
