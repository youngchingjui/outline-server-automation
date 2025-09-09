## EC2 update steps for outline-cycler cron fix

These changes fix truncated cron env causing corrupted PEM and ensure Lightsail instances are created with the correct key pair.

### 1) Pull new image or rebuild on EC2

- If you build locally and push:
  - docker compose pull
- If building on the server:
  - docker compose build --no-cache

### 2) Set required environment

- Ensure these env vars are present in your compose or host env:
  - AWS credentials (or rely on the EC2 IAM role)
  - AVAILABILITY_ZONE (e.g. ap-northeast-1a)
  - LIGHTSAIL_PRIVATE_KEY_BASE64 (single-line base64 of your PEM) or mount a file and set LIGHTSAIL_PRIVATE_KEY_FILE=/app/private.pem
  - LIGHTSAIL_KEYPAIR_NAME (Lightsail key pair that matches the PEM)

Notes:

- The container will decode LIGHTSAIL_PRIVATE_KEY_BASE64 at startup and write /app/private.pem with 0400 permissions. Cron will reference LIGHTSAIL_PRIVATE_KEY_FILE, not the base64.
- If both are set, LIGHTSAIL_PRIVATE_KEY_FILE is preferred.

### 3) Restart the container

```bash
docker compose up -d
```

### 4) Verify cron file and PEM inside container

```bash
docker exec -it outline-cycler sh -lc 'sed -n "1,200p" /etc/cron.d/outline-cycler'
```

- Expect small env lines. There should be no LIGHTSAIL_PRIVATE_KEY_BASE64 line.

```bash
docker exec -it outline-cycler sh -lc 'ls -l /app/private.pem && head -n 2 /app/private.pem'
```

- Should start with -----BEGIN (OPENSSH|RSA|EC) PRIVATE KEY-----

### 5) Dry-run the job manually

```bash
docker exec -it outline-cycler sh -lc 'LIGHTSAIL_PRIVATE_KEY_FILE=/app/private.pem bash /app/docker/run.sh; echo "exit=$?"'
```

### 6) Confirm instance uses your key pair

- In logs you should see: "Using key pair name: <LIGHTSAIL_KEYPAIR_NAME>". If you see "No key pair name provided", fix your env.

### 7) If SSH still fails

- Verify the Lightsail key pair’s public key matches /app/private.pem
- Try from your workstation with the same PEM:

```bash
ssh -i private.pem ubuntu@<lightsail-ip>
```

- If that works, compare to the container’s /app/private.pem contents.

### 8) Rollback

- To revert, redeploy the previous image/tag.
