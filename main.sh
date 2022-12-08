#!/bin/bash

# DEBUG: Exit immediately if any failures
# set -e

# DEBUG: Output each command as they are executed, for more visibility
# set -x

# Set key variable names
KEY_PAIR_FILENAME=LightsailDefaultKey-ap-northeast-2.pem
INSTALLATION_OUTPUT_FILEPATH=tmp/installation_output.txt
INSTANCE_NUMBER_FILEPATH=tmp/instance_number.txt

# Check if an instance name was provided as an argument
if [ -z "$1" ]; then    

    # Check if `instance_number.txt`` file exists
    if [ -f $INSTANCE_NUMBER_FILEPATH ]; then
    # The file exists, so load the data from the file
    instance_number=$(cat $INSTANCE_NUMBER_FILEPATH)

    else
    # The file does not exist, so create it and set the data to "1"
    echo "1" | tee $INSTANCE_NUMBER_FILEPATH
    instance_number=1
    fi

    # Generate the instance name based on the current instance number
    instance_name="outline-temp$instance_number"

else
    # Use the provided instance name
    instance_name=$1
fi

# Launch a new AWS Lightsail instance
echo "Creating new AWS Lightsail instance with name $instance_name"
aws lightsail create-instances --instance-name $instance_name --availability-zone "ap-northeast-2a" --blueprint-id "ubuntu_20_04" --bundle-id "nano_2_0"

if [ $? -ne 0 ]; then
    echo "Did not create instance successfully"
    exit 1
fi

# If instance launched successfully, increase the instance number
instance_number=$((++instance_number))
echo $instance_number | tee $INSTANCE_NUMBER_FILEPATH

# Wait for the instance to be launched
echo "Waiting for instance to finish launching"
while true; do
    state=$(aws lightsail get-instance --instance-name $instance_name | jq -r '.instance.state.name')
    if [ "$state" == "running" ]; then
        break
    fi
    echo "State: $state"
    sleep 5
done

# Get the public IP address of the instance
echo "Getting public IP address of instance"
instance_ip=$(aws lightsail get-instance --instance-name $instance_name | jq -r '.instance.publicIpAddress')
echo $instance_ip

# Open the necessary ports in the instance's firewall
echo "Opening necessary ports on the instance"
aws lightsail open-instance-public-ports --instance-name $instance_name --port-info fromPort=0,protocol=all,toPort=65535

# Check if INSTALLATION_OUTPUT_FILEPATH exists
if [ ! -f $INSTALLATION_OUTPUT_FILEPATH ]; then

    # Create the INSTALLATION_OUTPUT_FILEPATH file
    touch $INSTALLATION_OUTPUT_FILEPATH

fi

# Set the maximum number of attempts
max_attempts=5

# Set a counter variable to track the number of attempts
attempts=0

# Attempt to connect to the server in a loop
echo "Attempting to ssh into the server"
while [ $attempts -lt $max_attempts ]; do
  # Connect to the instance and run the remote-script, and save the output to `INSTALLATION_OUTPUT_FILEPATH`
  ssh -o StrictHostKeyChecking=no -i ~/.ssh/$KEY_PAIR_FILENAME ubuntu@$instance_ip 'bash -s' < ./scripts/remote-script.sh > $INSTALLATION_OUTPUT_FILEPATH
  if [ $? -eq 0 ]; then
    # The connection succeeded, so break out of the loop
    break
  else
    # The connection failed, so increment the attempts counter and try again
    attempts=$((attempts+1))
    echo "Failed attempt #$attempts"
    sleep 5
  fi
done

# Exit if 
if [ $attempts -eq $max_attempts ]; then
    echo "Could not connect to instance"
    exit 1
fi

# Pull the connection API out of the INSTALLATION_OUTPUT_FILEPATH
echo "Getting Outline server API URL"
apiURL=$(cat $INSTALLATION_OUTPUT_FILEPATH | sed -n 's/.*"\(https:\/\/[^"]*\)".*/\1/p')
echo $apiURL

# Reset `attempts` variable back to 0
attempts=0

# Attempt to make curl request
echo "Attempting to get access keys"
while [ $attempts -lt $max_attempts ]; do
    # Get the list of access keys, and get the first access key
    ssLink=$(curl --insecure $apiURL/access-keys | jq -r '.accessKeys[0].accessUrl')
    echo $ssLink

    if [ $? -eq 0 ]; then
        # The connection succeeded, so break out of the loop
        break
    else
        # The connection failed, so increment the attempts counter and try again
        attempts=$((attempts+1))
        echo "Failed attempt #$attempts"
        sleep 1
    fi
done

# Upload the new ssLink to S3
. ./scripts/upload-sslink-to-s3.sh $ssLink

# Once all setup, delete all older Lightsail instances, except for the newest one installed
. ./scripts/delete-all-lightsail-instances-except-this.sh $instance_name





