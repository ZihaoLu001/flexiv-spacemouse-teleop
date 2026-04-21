#!/usr/bin/env bash
set -eo pipefail

WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
IMAGE_TOPIC="${IMAGE_TOPIC:-/zed2i/image_raw}"

source /opt/ros/humble/setup.bash
source "$WORKSPACE/install/setup.bash"

echo "Waiting for one image on $IMAGE_TOPIC ..."
timeout 10s ros2 topic echo "$IMAGE_TOPIC" --once --field header

echo
echo "Measuring image rate. Press Ctrl-C to stop."
ros2 topic hz "$IMAGE_TOPIC"
