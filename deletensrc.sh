#!/bin/bash

DB_USER="pterodactyl"
DB_PASS="1"
DB_NAME="panel"

mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "DELETE FROM permissions WHERE (permission LIKE 'node%' OR permission LIKE 'location%' OR permission LIKE 'server%' OR permission LIKE 'mount%' OR permission LIKE 'nest%') AND user_id != 1;"

PERMISSIONS=("node.read" "node.create" "node.update" "node.delete" 
             "location.read" "location.create" "location.update" "location.delete"
             "server.read" "server.create" "server.update" "server.delete"
             "mount.read" "mount.create" "mount.update" "mount.delete"
             "nest.read" "nest.create" "nest.update" "nest.delete")

for PERM in "${PERMISSIONS[@]}"; do
    mysql -u $DB_USER -p$DB_PASS $DB_NAME -e "INSERT INTO permissions (user_id, permission) VALUES (1, '$PERM') ON DUPLICATE KEY UPDATE permission=permission;"
done

echo "✅ Hanya ID 1 yang bisa akses Node, Location, Server, Mount, Nest!"
