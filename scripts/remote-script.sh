#!/bin/bash

# DEBUG: Exit immediately if any failures
# set -e

# DEBUG: Output each command as they are executed, for more visibility
# set -x

# First, install Docker
curl https://get.docker.com/ | sh

# After Docker is installed, install Outline
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh)"

# Disconnect from remote server
exit 0