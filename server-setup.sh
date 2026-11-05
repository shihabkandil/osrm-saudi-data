#!/usr/bin/env bash
set -euo pipefail

TARBALL=${1:?usage: bash server-setup.sh osrm-gcc-YYYY-MM-DD-amd64.tar.gz}
RELEASE=$(basename "$TARBALL" .tar.gz)
IMG=ghcr.io/project-osrm/osrm-backend:v6.0.0
OSRM_DIR=/opt/osrm

[ "$(uname -m)" = "x86_64" ] || { echo "This dataset was built for x86_64, but this server is $(uname -m)."; exit 1; }

echo "== Checking the upload"
(cd "$(dirname "$TARBALL")" && sha256sum -c "$(basename "$TARBALL").sha256")

echo "== Disk and memory before"
df -h / | tail -1
free -m | head -2

if [ "$(df --output=avail -BG / | tail -1 | tr -dc 0-9)" -lt 4 ]; then
  echo "Need at least 4GB free on / (about 2.3GB for the data plus room for the image)."; exit 1
fi

if ! swapon --show | grep -q '/swapfile'; then
  echo "== Adding a 4GB swap file"
  sudo fallocate -l 4G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

if ! command -v docker >/dev/null; then
  echo "== Installing Docker"
  sudo apt-get update
  sudo apt-get install -y docker.io
  sudo systemctl enable --now docker
fi

echo "== Unpacking $RELEASE"
sudo mkdir -p "$OSRM_DIR/releases/$RELEASE"
sudo tar -xzf "$TARBALL" -C "$OSRM_DIR/releases/$RELEASE"
sudo ln -sfn "$OSRM_DIR/releases/$RELEASE" "$OSRM_DIR/current"

echo "== Starting OSRM (CH, --mmap=1, localhost only)"
sudo docker pull -q "$IMG"
sudo docker rm -f osrm >/dev/null 2>&1 || true
sudo docker run -d --name osrm --restart unless-stopped \
  --memory=1g --cpus=1.5 \
  -p 127.0.0.1:5000:5000 \
  -v "$OSRM_DIR/current:/data:ro" \
  "$IMG" \
  osrm-routed --algorithm ch --mmap=1 --max-table-size 100 /data/gcc-states.osrm

echo "== Waiting for OSRM"
for _ in $(seq 1 60); do
  curl -sf -o /dev/null "http://127.0.0.1:5000/route/v1/driving/46.6753,24.7136;46.7386,24.7743?overview=false" && break
  sleep 1
done

echo "== Route (car-saudi.lua build: expect distance about 14133, duration about 1030)"
curl -s "http://127.0.0.1:5000/route/v1/driving/46.6753,24.7136;46.7386,24.7743?overview=false" | head -c 300; echo
echo "== Table (expect 3 distances and 3 durations)"
curl -s "http://127.0.0.1:5000/table/v1/driving/46.6753,24.7136;46.7386,24.7743;46.6388,24.6908;46.7100,24.8200?sources=0&destinations=1;2;3&annotations=distance,duration" | head -c 400; echo

echo "== Memory after"
free -m | head -2
sudo docker stats --no-stream osrm
ls -1 "$OSRM_DIR/releases"
