#!/bin/bash

SS_LINK_FILEPATH=sslink.txt

# Remove temp files on exit
trap "rm -f $SS_LINK_FILEPATH" EXIT

# Retrieve ssLink from input
ssLink=$1

echo "Uploading ss key $ssLink to S3"

# Save the access key in `sslink.txt`
echo $ssLink > $SS_LINK_FILEPATH

# Copy the updated `SS_LINK_FILEPATH` to AWS S3 bucket
aws s3 cp $SS_LINK_FILEPATH s3://outline-link/sslink.txt --acl public-read