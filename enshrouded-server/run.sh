#!/bin/bash
set -x

echo "=== Starting Enshrouded ==="

mkdir -p /mnt/enshrouded/persistentdata/settings

if [ ! -f /mnt/enshrouded/persistentdata/settings/enshrouded_server.json ]; then
    cp /root/enshrouded_server_example.json \
       /mnt/enshrouded/persistentdata/settings/enshrouded_server.json
fi

exec wine /mnt/enshrouded/server/enshrouded_server.exe \
  --config /mnt/enshrouded/persistentdata/settings/enshrouded_server.json
