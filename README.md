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
  -b ubuntu_24_04 \
  -B nano_2_0 \
  -r us-east-1 \
  -z us-east-1a \
  -k my-keypair \
  -t "key=Project,value=Outline key=Env,value=Dev" \
  -u ./scripts/remote-script.sh
```

Flags:

- `-n` Instance name (required)
- `-b` Blueprint ID (default: `ubuntu_24_04`)
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

---

## Run as a Dockerized cron service on your own EC2 server

This repository now includes a Docker image and docker-compose setup that runs the automation every 6 hours via cron inside the container.

What it does on each run:

- Creates a new AWS Lightsail instance
- Installs Outline via the official install script
- Retrieves the access key (ss URL) from the Outline API
- Uploads the connection string to S3
- Optionally deletes older Lightsail instances to save cost

### Prerequisites on your EC2 server

- Docker and Docker Compose installed
- AWS permissions available to the container via either:
  - Instance profile (recommended): Attach an IAM role to the EC2 instance with permissions for Lightsail and S3
  - Or environment variables: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, optional `AWS_SESSION_TOKEN`, and `AWS_REGION`
- A Lightsail key pair in the target region, and the corresponding private key content available as a base64-encoded, single-line string

Tip: to base64-encode your Lightsail SSH private key file into a single line suitable for an env var:

```bash
base64 -w 0 < /path/to/LightsailDefaultKey-<region>.pem
```

### Configure and start

1. Create a `.env` file next to `docker-compose.yml` with at least:

```
# Either rely on EC2 instance role or set these explicitly
AWS_REGION=ap-northeast-2
# AWS_ACCESS_KEY_ID=...
# AWS_SECRET_ACCESS_KEY=...
# AWS_SESSION_TOKEN=...

# Required: base64 (single-line) of your Lightsail private key for the region
LIGHTSAIL_PRIVATE_KEY_BASE64=...base64-blob...

# Optional overrides
# AVAILABILITY_ZONE=ap-northeast-1a
# CRON_SCHEDULE=0 */6 * * *
# S3_URI=s3://my-bucket/custom/path.txt
# S3_BUCKET=my-bucket
# S3_KEY=sslink.txt
# S3_ACL=public-read
# TZ=UTC
```

Notes:

- Provide either `S3_URI` (full `s3://bucket/key`) or `S3_BUCKET` (and optional `S3_KEY`). If neither is provided, the default `s3://outline-link/sslink.txt` is used.
- `CRON_SCHEDULE` uses standard cron syntax. Default is every 6 hours.
- If your EC2 instance has an IAM role, you can omit the AWS credential env vars.

2. Start the service:

```bash
docker compose up -d --build
```

3. View logs:

```bash
docker logs -f outline-cycler
# or tail the cron log persisted to the host
 tail -f logs/cron.log
```

### Secure configuration

- Prefer using an EC2 instance profile (IAM role) to grant AWS permissions to the container. This avoids storing AWS keys on disk.
- Store `LIGHTSAIL_PRIVATE_KEY_BASE64` in your `.env` file or a secret manager. The value must match the Lightsail region's default key pair used by `create-instances`.
- Limit the IAM role/keys to the minimum necessary permissions: Lightsail create/get/open-ports/delete; S3 put object to your configured bucket/key.

### Customization

- Region and AZ: Set `AWS_REGION` and optional `AVAILABILITY_ZONE`.
- S3 destination: Set `S3_URI` directly, or `S3_BUCKET` and optional `S3_KEY`. Default ACL is `public-read` (override with `S3_ACL`).
- Schedule: Change `CRON_SCHEDULE` to adjust frequency.
- Deletion behavior: By default the workflow deletes older instances after a successful run. To disable, run `main.sh --do-not-delete`. You can adapt `docker/run.sh` to pass this flag if desired.

---

## S3 upload configuration

The upload script supports environment variables:

- `S3_URI` (full URI) or `S3_BUCKET` and optional `S3_KEY` (defaults to `sslink.txt`).
- `S3_ACL` for object ACL (defaults to `public-read`).

---

## Alternatives to cycling Lightsail IPs

See `docs/ALTERNATIVES.md` for other approaches to rotate or shield IP addresses to reduce blocking while keeping costs in check.
