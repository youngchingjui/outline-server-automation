# outline-server-automation

Automation script for launching and managing new Outline servers

This script automatically launches a Lightsail server instance, installs Outline on it, then uploads the new key to an S3 bucket.

User needs to be logged in with the `aws cli` first.

You'll also need a default key-pair to connect to the Lightsail server instance. They key-pair should be saved at ~/.ssh folder.

## Create a Lightsail instance

A simple, environment-agnostic helper is available at `scripts/create-lightsail-instance.sh`. It accepts AWS auth and region via your existing AWS CLI configuration, environment variables, or explicit flags.

Example usage:

```bash
./scripts/create-lightsail-instance.sh \
  -n my-outline \
  -b ubuntu_22_04 \
  -B nano_2_0 \
  -r us-east-1 \
  -z us-east-1a \
  -k my-keypair \
  -t "key=Project,value=Outline key=Env,value=Dev" \
  -u ./scripts/remote-script.sh
```

Flags:

- `-n` Instance name (required)
- `-b` Blueprint ID (default: `ubuntu_22_04`)
- `-B` Bundle ID (default: `nano_2_0`)
- `-r` Region (falls back to `AWS_REGION` or AWS CLI default)
- `-z` Availability Zone (e.g., `us-east-1a`)
- `-k` Lightsail key-pair name
- `-t` Tags (e.g., `"key=Env,value=Dev key=Project,value=Outline"`). Uppercase `Key=`/`Value=` are also accepted and normalized.
- `-u` User data file (cloud-init or script). Contents are passed to `--user-data`.

Authentication can be provided via any standard AWS mechanism:

- Environment variables: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_REGION`
- AWS profiles: `aws --profile <name>` or set `AWS_PROFILE`
- IAM roles on CI/compute environments
