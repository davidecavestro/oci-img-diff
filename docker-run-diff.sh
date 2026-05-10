#!/bin/bash

# Configuration
TOOL_IMAGE="imgdiff"
# Default output directory is current working directory
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)}"

# Ensure we are in the directory containing the Dockerfile
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🛠️  Building $TOOL_IMAGE..."
# Build quietly to keep the focus on the diff results
docker build -t "$TOOL_IMAGE" . -q

echo "🚀 Launching container..."

# We pass "$@" which forwards all flags (-1, -2, -p, -f, -s) 
# directly to the entrypoint inside the container.
docker run --rm \
  -e DFT_WIDTH=200 \
  -v /tmp \
  -v "$HOME/.docker/config.json:/root/.docker/config.json:ro" \
  -v "$OUTPUT_DIR":/output \
  "$TOOL_IMAGE" "$@"

# Check if the process succeeded
if [ $? -eq 0 ]; then
    echo "✨ Workflow finished successfully."
else
    echo "❌ Workflow failed. Check the logs above."
    exit 1
fi