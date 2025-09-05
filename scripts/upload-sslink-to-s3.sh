#!/bin/bash

SS_LINK_FILEPATH=sslink.txt

# Remove temp files on exit
trap "rm -f $SS_LINK_FILEPATH" EXIT

# Retrieve ssLink from input
ssLink=$1

if [ -z "$ssLink" ]; then
  echo "No Shadowsocks link provided to upload-sslink-to-s3.sh"
  exit 1
fi

# Determine destination S3 URI
# Priority: S3_URI env > S3_BUCKET (+ optional S3_KEY) > default bucket/path
DEST_URI="${S3_URI:-}"
if [ -z "$DEST_URI" ]; then
  if [ -n "${S3_BUCKET:-}" ]; then
    DEST_URI="s3://${S3_BUCKET}/${S3_KEY:-sslink.txt}"
  else
    DEST_URI="s3://outline-link/sslink.txt"
  fi
fi

ACL_OPT="${S3_ACL:-public-read}"

echo "Uploading ss key to $DEST_URI (acl=$ACL_OPT)"

# Save the access key in `sslink.txt`
echo "$ssLink" > "$SS_LINK_FILEPATH"

# Copy the updated `SS_LINK_FILEPATH` to AWS S3 bucket
aws s3 cp "$SS_LINK_FILEPATH" "$DEST_URI" --acl "$ACL_OPT"

