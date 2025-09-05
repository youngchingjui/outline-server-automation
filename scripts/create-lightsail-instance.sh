#!/bin/bash

# Creates a new AWS Lightsail instance in an environment-agnostic way.
#
# Requirements:
# - AWS CLI installed and authenticated (env vars or profile)
# - Lightsail service enabled in the target region
#
# Example:
#   scripts/create-lightsail-instance.sh \
#     -n my-outline \
#     -b ubuntu_24_04 \
#     -B nano_2_0 \
#     -r us-east-1 \
#     -z us-east-1a \
#     -k my-keypair \
#     -t "Key=Project,Value=Outline" \
#     -u ./cloud-init.sh

usage() {
  echo "Usage: $0 -n <instance-name> [-b <blueprint-id>] [-B <bundle-id>] [-r <region>] [-z <availability-zone>] [-k <key-pair-name>] [-t <tags>] [-u <user-data-file>]"
  echo
  echo "Options:"
  echo "  -n   Instance name (required)"
  echo "  -b   Blueprint ID (default: ubuntu_24_04)"
  echo "  -B   Bundle ID (default: nano_2_0)"
  echo "  -r   AWS region (defaults to AWS CLI config/AWS_REGION env)"
  echo "  -z   Availability zone (e.g., us-east-1a)"
  echo "  -k   Lightsail key pair name"
  echo "  -t   Tags string passed to --tags as-is (e.g., 'Key=Env,Value=Dev Key=Project,Value=Outline')"
  echo "  -u   Path to user-data file (cloud-init or shell script)"
}

INSTANCE_NAME=""
BLUEPRINT_ID="${BLUEPRINT_ID:-ubuntu_24_04}"
BUNDLE_ID="${BUNDLE_ID:-nano_2_0}"
REGION="${AWS_REGION:-${REGION:-}}"
AVAILABILITY_ZONE="${AVAILABILITY_ZONE:-}"
KEY_PAIR_NAME="${KEY_PAIR_NAME:-}"
TAGS="${TAGS:-}"
USER_DATA_FILE=""

while getopts ":n:b:B:r:z:k:t:u:h" opt; do
  case ${opt} in
    n) INSTANCE_NAME="$OPTARG" ;;
    b) BLUEPRINT_ID="$OPTARG" ;;
    B) BUNDLE_ID="$OPTARG" ;;
    r) REGION="$OPTARG" ;;
    z) AVAILABILITY_ZONE="$OPTARG" ;;
    k) KEY_PAIR_NAME="$OPTARG" ;;
    t) TAGS="$OPTARG" ;;
    u) USER_DATA_FILE="$OPTARG" ;;
    h) usage; exit 0 ;;
    :) echo "Error: -$OPTARG requires an argument"; usage; exit 1 ;;
    \?) echo "Error: invalid option -$OPTARG"; usage; exit 1 ;;
  esac
done

if [ -z "$INSTANCE_NAME" ]; then
  echo "Error: instance name (-n) is required"
  usage
  exit 1
fi

# Build CLI arguments
ARGS=(
  --instance-names "$INSTANCE_NAME"
  --blueprint-id "$BLUEPRINT_ID"
  --bundle-id "$BUNDLE_ID"
)

if [ -n "$AVAILABILITY_ZONE" ]; then
  ARGS+=( --availability-zone "$AVAILABILITY_ZONE" )
fi

if [ -n "$REGION" ]; then
  ARGS+=( --region "$REGION" )
fi

if [ -n "$KEY_PAIR_NAME" ]; then
  ARGS+=( --key-pair-name "$KEY_PAIR_NAME" )
fi

if [ -n "$TAGS" ]; then
  # Normalize to lowercase keys expected by AWS CLI: key=,value=
  # Supports inputs like: "Key=Env,Value=Dev Key=Project,Value=Outline"
  NORMALIZED_TAGS=$(echo "$TAGS" | sed -E 's/(^|[ ,])Key=/\1key=/g; s/(^|[ ,])Value=/\1value=/g')
  ARGS+=( --tags $NORMALIZED_TAGS )
fi

if [ -n "$USER_DATA_FILE" ]; then
  if [ ! -f "$USER_DATA_FILE" ]; then
    echo "Error: user-data file not found: $USER_DATA_FILE"
    exit 1
  fi
  # Use file:// syntax so AWS CLI reads content safely (handles newlines/size)
  ARGS+=( --user-data file://"$USER_DATA_FILE" )
fi

echo "Creating Lightsail instance '$INSTANCE_NAME'..."
if [ -n "$REGION" ]; then
  echo "Region: $REGION"
fi
if [ -n "$AVAILABILITY_ZONE" ]; then
  echo "AZ: $AVAILABILITY_ZONE"
fi
echo "Blueprint: $BLUEPRINT_ID | Bundle: $BUNDLE_ID"

aws lightsail create-instances "${ARGS[@]}"
CREATE_EXIT=$?
if [ $CREATE_EXIT -ne 0 ]; then
  echo "Failed to create instance. AWS CLI exit code: $CREATE_EXIT"
  exit $CREATE_EXIT
fi

echo "Waiting for instance to enter running state..."
STATE="pending"
ATTEMPTS=0
MAX_ATTEMPTS=60
SLEEP_SECONDS=5

while [ "$STATE" != "running" ] && [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
  STATE=$(aws lightsail get-instance --instance-name "$INSTANCE_NAME" ${REGION:+--region "$REGION"} --query 'instance.state.name' --output text 2>/dev/null || echo "unknown")
  if [ "$STATE" = "running" ]; then
    break
  fi
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep $SLEEP_SECONDS
done

IP=$(aws lightsail get-instance --instance-name "$INSTANCE_NAME" ${REGION:+--region "$REGION"} --query 'instance.publicIpAddress' --output text 2>/dev/null || true)

echo "InstanceName: $INSTANCE_NAME"
echo "State: $STATE"
if [ -n "$IP" ] && [ "$IP" != "None" ]; then
  echo "PublicIP: $IP"
fi

if [ "$STATE" != "running" ]; then
  echo "Instance is not in running state yet. You may check again later:"
  echo "  aws lightsail get-instance --instance-name $INSTANCE_NAME ${REGION:+--region $REGION} --query 'instance.{State:state.name,IP:publicIpAddress}'"
fi

exit 0


