#!/bin/bash

# Deletes all Lightsail instances except for this one

# Retrieve the instance name to NOT delete
instance_name=$1

echo "Deleting all other instances except for $instance_name"

# Get the list of instance names
INSTANCE_NAMES=$(aws lightsail get-instances | jq -r '.instances[].name' | grep -v $instance_name)
echo "Deleting these instances:"
echo $INSTANCE_NAMES

# Iterate over the list of instance names
for INSTANCE_NAME in $INSTANCE_NAMES; do
  # Delete the current instance
  aws lightsail delete-instance --instance-name $INSTANCE_NAME
done