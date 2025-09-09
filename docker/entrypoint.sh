#!/usr/bin/env bash
set -euo pipefail

# Create cron file with environment variables and schedule
CRON_FILE="/etc/cron.d/outline-cycler"
LOG_FILE="/var/log/cron.log"

# Ensure log file exists
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Decode the Lightsail private key once at container startup
if [ -n "${LIGHTSAIL_PRIVATE_KEY_BASE64-}" ]; then
  umask 077
  if ! printf %s "$LIGHTSAIL_PRIVATE_KEY_BASE64" | base64 -d > /app/private.pem; then
    echo "[entrypoint] ERROR: Could not decode LIGHTSAIL_PRIVATE_KEY_BASE64" >> "$LOG_FILE"
    exit 1
  fi
fi

# Default schedule if not provided
: "${CRON_SCHEDULE:=0 */6 * * *}"

# Helper to append a VAR=value line if set
append_env() {
  local var="$1"
  if [ -n "${!var-}" ]; then
    # Do not quote; cron treats quotes as literal characters
    echo "$var=${!var}" >> "$CRON_FILE"
  fi
}

# Build cron file
{
  echo "SHELL=/bin/bash"
  echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
} > "$CRON_FILE"

# Pass through selected environment variables for the job
for v in \
  AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN \
  AWS_REGION AWS_DEFAULT_REGION AWS_PROFILE \
  AVAILABILITY_ZONE LIGHTSAIL_KEYPAIR_NAME LIGHTSAIL_PRIVATE_KEY_FILE \
  S3_URI S3_BUCKET S3_KEY S3_ACL TZ \
  DELETE_INSTANCES INSTANCE_NAME
do
  append_env "$v"
done

# If a decoded key exists, advertise the path to the cron job
if [ -f /app/private.pem ]; then
  echo "LIGHTSAIL_PRIVATE_KEY_FILE=/app/private.pem" >> "$CRON_FILE"
fi

# Cron job line: run every N hours and log output
{
  echo ""
  echo "$CRON_SCHEDULE root /app/docker/run.sh >> $LOG_FILE 2>&1"
} >> "$CRON_FILE"

# Correct permissions per cron.d requirements
chmod 0644 "$CRON_FILE"

# Print the cron file for visibility
echo "[entrypoint] Installed cron file:" && cat "$CRON_FILE"

# Start cron in foreground
exec cron -f -L 2

