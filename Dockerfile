# Docker image to run Lightsail Outline cycler via cron
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies: awscli, jq, ssh client, curl/wget, cron, tzdata
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
       ca-certificates \
       awscli \
       jq \
       openssh-client \
       curl \
       wget \
       cron \
       tzdata \
  && rm -rf /var/lib/apt/lists/*

# App directory
WORKDIR /app

# Copy repository contents
COPY . /app

# Ensure scripts are executable
RUN chmod +x /app/main.sh \
    && find /app/scripts -type f -name "*.sh" -exec chmod +x {} + \
    && chmod +x /app/docker/entrypoint.sh /app/docker/run.sh

# Create logs directory
RUN mkdir -p /var/log \
    && touch /var/log/cron.log

# Default cron schedule (every 6 hours). Can be overridden with env CRON_SCHEDULE
ENV CRON_SCHEDULE="0 */6 * * *"

# Start cron in foreground via entrypoint (also writes cron file)
ENTRYPOINT ["/app/docker/entrypoint.sh"]

