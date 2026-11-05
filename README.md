# OSRM data for Saudi Arabia (GCC)

Prebuilt [OSRM](https://github.com/Project-OSRM/osrm-backend) routing data for driving in Saudi Arabia and the rest of the GCC, ready to serve with Docker.

Download the files from [Releases](../../releases).

| Release | Map data | Profile | Algorithm | Built for |
|---|---|---|---|---|
| `gcc-2026-10-31-saudi` | Geofabrik GCC extract, 2026-10-31 | `car-saudi.lua` | CH | x86_64 (amd64) |

## Files in each release

- `osrm-gcc-<date>-saudi-amd64.tar.gz`: the routing data (unpacks to about 2.3 GB)
- `osrm-gcc-<date>-saudi-amd64.tar.gz.sha256`: checksum
- `server-setup.sh`: unpacks the data and starts OSRM in Docker on an x86 Ubuntu server
- `car-saudi.lua`: the car profile the data was built with

## Install on a server

The repo is private, so downloads need a fine-grained GitHub token with read-only **Contents** access to this repo. The files are fetched by release asset ID through the API:

```bash
read -s -p "GitHub token: " TOKEN; echo
mkdir -p /tmp/osrm-upload && cd /tmp/osrm-upload
API=https://api.github.com/repos/shihabkandil/osrm-saudi-data/releases/assets
get() { curl -fSL -H "Authorization: Bearer $TOKEN" -H "Accept: application/octet-stream" -o "$2" "$API/$1"; }
get 713841594 osrm-gcc-2026-10-31-saudi-amd64.tar.gz
get 713715597 osrm-gcc-2026-10-31-saudi-amd64.tar.gz.sha256
get 713715594 server-setup.sh
unset TOKEN
bash server-setup.sh osrm-gcc-2026-10-31-saudi-amd64.tar.gz
```

For another release, list its asset IDs with `gh api repos/shihabkandil/osrm-saudi-data/releases/tags/<tag> -q '.assets[] | "\(.id) \(.name)"'`.

OSRM then listens on `127.0.0.1:5000` with `osrm-routed --algorithm ch --mmap=1` (image `ghcr.io/project-osrm/osrm-backend:v6.0.0`).

## The `car-saudi.lua` profile

It's the stock OSRM v6.0.0 car profile with slower city driving, calibrated against Google Maps on trips in Riyadh and Jeddah:

- City roads run at 50% of the posted speed limit instead of 80%. Motorways and trunk roads keep 80%, so intercity times stay realistic.
- City roads with no posted limit use 65% of the stock speeds.
- Each traffic light adds 30 seconds instead of 2.

## Build it yourself

```bash
IMG=ghcr.io/project-osrm/osrm-backend:v6.0.0
curl -L -o gcc-states.osm.pbf https://download.geofabrik.de/asia/gcc-states-latest.osm.pbf
docker run --rm --platform linux/amd64 -v "$PWD:/data" -v "$PWD/car-saudi.lua:/opt/car-saudi.lua:ro" $IMG \
  osrm-extract -p /opt/car-saudi.lua /data/gcc-states.osm.pbf
docker run --rm --platform linux/amd64 -v "$PWD:/data" $IMG osrm-contract /data/gcc-states.osrm
```

The extract step needs about 6 GB of RAM.

## License

Contains data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), available under the [Open Database License (ODbL)](https://opendatacommons.org/licenses/odbl/). The routing data in the releases is a derived database and is shared under the same license.
