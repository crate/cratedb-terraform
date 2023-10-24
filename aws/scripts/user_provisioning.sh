#!/bin/bash

protocol="${1}"
username="${2}"
password="${3}"

send_sql() {
    curl -sS -H 'Content-Type: application/json' -k -X POST "${protocol}://localhost:4200/_sql" -d "$1"
}

generate_body() {
    jq -n --arg stmt "$1" '{"stmt": $stmt}'
}

sleep 30

send_sql "$(generate_body "CREATE USER ${username} WITH (password = \$\$${password}\$\$)")"
send_sql "$(generate_body "GRANT ALL PRIVILEGES TO ${username}")"
