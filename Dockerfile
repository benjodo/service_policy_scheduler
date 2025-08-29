FROM debian:bullseye-slim

# Set timezone to Central Time
ENV TZ=America/Chicago
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install required packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    ca-certificates \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Install Aptible CLI
RUN wget -O /tmp/aptible-toolbelt.deb https://omnibus-aptible-toolbelt.s3.amazonaws.com/aptible/omnibus-aptible-toolbelt/latest/aptible-toolbelt_latest_debian-9_amd64.deb \
    && dpkg -i /tmp/aptible-toolbelt.deb || apt-get install -f -y \
    && rm /tmp/aptible-toolbelt.deb

# Install Supercronic
RUN SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.30/supercronic-linux-amd64 \
    && SUPERCRONIC=supercronic-linux-amd64 \
    && SUPERCRONIC_SHA1SUM=9f27ad28c5c57cd133325b2a66bba69ba2235799 \
    && curl -fsSLO "$SUPERCRONIC_URL" \
    && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
    && chmod +x "$SUPERCRONIC" \
    && mv "$SUPERCRONIC" "/usr/local/bin/supercronic"

# Create app directory
WORKDIR /app

# Copy Procfile, crontab and scripts
COPY Procfile .
COPY crontab .
COPY autoscaling.sh .
RUN chmod +x autoscaling.sh