#!/usr/bin/env bash
set -euo pipefail
cd /app

echo "[$(date -Iseconds)] Starting Outline Lightsail cycler run"

# Run the main workflow
bash ./main.sh

EXIT_CODE=$?

echo "[$(date -Iseconds)] Completed run with exit code: $EXIT_CODE"
exit $EXIT_CODE

