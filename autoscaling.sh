#!/bin/bash

# Aptible autoscaling policy update script
# Usage: ./autoscaling.sh [busy|off]

set -e

MODE=$1

if [ -z "$MODE" ]; then
    echo "Usage: $0 [busy|off]"
    exit 1
fi

# Check required environment variables
REQUIRED_VARS=(
    "SERVICE"
    "APP_HANDLE"
    "APP_ENVIRONMENT"
    "MIN_CONTAINERS_BUSY_HOURS"
    "MAX_CONTAINERS_BUSY_HOURS"
    "MIN_CONTAINERS_OFF_HOURS"
    "MAX_CONTAINERS_OFF_HOURS"
    "APTIBLE_USER_EMAIL"
    "APTIBLE_USER_PASSWORD"
)

MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    echo "$(date): ERROR: Missing required environment variables:"
    for var in "${MISSING_VARS[@]}"; do
        echo "  - $var"
    done
    echo "$(date): Please configure these variables in your Aptible app configuration"
    exit 1
fi

# Set container limits based on mode
if [ "$MODE" = "busy" ]; then
    MIN_CONTAINERS=$MIN_CONTAINERS_BUSY_HOURS
    MAX_CONTAINERS=$MAX_CONTAINERS_BUSY_HOURS
    echo "$(date): Setting busy hours policy - min: $MIN_CONTAINERS, max: $MAX_CONTAINERS"
elif [ "$MODE" = "off" ]; then
    MIN_CONTAINERS=$MIN_CONTAINERS_OFF_HOURS
    MAX_CONTAINERS=$MAX_CONTAINERS_OFF_HOURS
    echo "$(date): Setting off hours policy - min: $MIN_CONTAINERS, max: $MAX_CONTAINERS"
else
    echo "Invalid mode: $MODE. Use 'busy' or 'off'"
    exit 1
fi

# Login to Aptible
echo "$(date): Logging into Aptible..."
aptible login --email="$APTIBLE_USER_EMAIL" --password="$APTIBLE_USER_PASSWORD"

if [ $? -ne 0 ]; then
    echo "$(date): Failed to login to Aptible"
    exit 1
fi

# Execute the aptible command
echo "$(date): Executing aptible services:autoscaling_policy:set..."
aptible services:autoscaling_policy:set "$SERVICE" \
    --app="$APP_HANDLE" \
    --environment="$APP_ENVIRONMENT" \
    --min-containers="$MIN_CONTAINERS" \
    --max-containers="$MAX_CONTAINERS"

if [ $? -eq 0 ]; then
    echo "$(date): Successfully updated autoscaling policy for $SERVICE"
else
    echo "$(date): Failed to update autoscaling policy for $SERVICE"
    exit 1
fi