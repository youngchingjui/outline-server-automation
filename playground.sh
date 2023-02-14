#!/bin/bash

echo "Testing access to S3 bucket"

TEST_FILEPATH=test.txt
touch $TEST_FILEPATH

echo "Test file" > $TEST_FILEPATH

aws s3 cp $TEST_FILEPATH "s3://outline-link/$TEST_FILEPATH" --acl public-read