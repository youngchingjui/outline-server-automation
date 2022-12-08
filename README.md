# outline-server-automation

Automation script for launching and managing new Outline servers

This script automatically launches a Lightsail server instance, installs Outline on it, then uploads the new key to an S3 bucket.

User needs to be logged in with the `aws cli` first.

You'll also need a default key-pair to connect to the Lightsail server instance. They key-pair should be saved at ~/.ssh folder.