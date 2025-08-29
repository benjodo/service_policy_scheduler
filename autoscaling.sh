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

# Fetch current autoscaling policy
echo "$(date): Fetching current autoscaling policy..."
POLICY_JSON=$(APTIBLE_OUTPUT_FORMAT=json aptible services:autoscaling_policy "$SERVICE" --app="$APP_HANDLE" --environment="$APP_ENVIRONMENT")

if [ $? -ne 0 ]; then
    echo "$(date): Failed to fetch current autoscaling policy"
    exit 1
fi

# Check if horizontal autoscaling is enabled
AUTOSCALING_TYPE=$(echo "$POLICY_JSON" | jq -r '.autoscaling_type')
if [ "$AUTOSCALING_TYPE" != "horizontal" ]; then
    echo "$(date): ERROR: Horizontal autoscaling is not enabled for $SERVICE"
    echo "$(date): Current autoscaling type: $AUTOSCALING_TYPE"
    echo "$(date): Please enable horizontal autoscaling before using this scheduler"
    exit 1
fi

# Extract existing parameters (only horizontal autoscaling parameters)
METRIC_LOOKBACK=$(echo "$POLICY_JSON" | jq -r '.metric_lookback_seconds')
PERCENTILE=$(echo "$POLICY_JSON" | jq -r '.percentile')
POST_SCALE_UP_COOLDOWN=$(echo "$POLICY_JSON" | jq -r '.post_scale_up_cooldown_seconds')
POST_SCALE_DOWN_COOLDOWN=$(echo "$POLICY_JSON" | jq -r '.post_scale_down_cooldown_seconds')
POST_RELEASE_COOLDOWN=$(echo "$POLICY_JSON" | jq -r '.post_release_cooldown_seconds')
MIN_CPU_THRESHOLD=$(echo "$POLICY_JSON" | jq -r '.min_cpu_threshold')
MAX_CPU_THRESHOLD=$(echo "$POLICY_JSON" | jq -r '.max_cpu_threshold')
SCALE_UP_STEP=$(echo "$POLICY_JSON" | jq -r '.scale_up_step')
SCALE_DOWN_STEP=$(echo "$POLICY_JSON" | jq -r '.scale_down_step')
RESTART_FREE_SCALE=$(echo "$POLICY_JSON" | jq -r '.restart_free_scale')

# Execute the aptible command with all existing parameters preserved
echo "$(date): Executing aptible services:autoscaling_policy:set..."
COMMAND_ARGS=(
    "$SERVICE"
    --app="$APP_HANDLE"
    --environment="$APP_ENVIRONMENT"
    --autoscaling-type="horizontal"
    --min-containers="$MIN_CONTAINERS"
    --max-containers="$MAX_CONTAINERS"
    --metric-lookback-seconds="$METRIC_LOOKBACK"
    --percentile="$PERCENTILE"
    --post-scale-up-cooldown-seconds="$POST_SCALE_UP_COOLDOWN"
    --post-scale-down-cooldown-seconds="$POST_SCALE_DOWN_COOLDOWN"
    --post-release-cooldown-seconds="$POST_RELEASE_COOLDOWN"
    --min-cpu-threshold="$MIN_CPU_THRESHOLD"
    --max-cpu-threshold="$MAX_CPU_THRESHOLD"
    --scale-up-step="$SCALE_UP_STEP"
    --scale-down-step="$SCALE_DOWN_STEP"
)

# Add restart-free-scale flag if it's enabled
if [ "$RESTART_FREE_SCALE" = "true" ]; then
    COMMAND_ARGS+=(--restart-free-scale)
else
    COMMAND_ARGS+=(--no-restart-free-scale)
fi

aptible services:autoscaling_policy:set "${COMMAND_ARGS[@]}"

if [ $? -eq 0 ]; then
    echo "$(date): Successfully updated autoscaling policy for $SERVICE"
else
    echo "$(date): Failed to update autoscaling policy for $SERVICE"
    exit 1
fi