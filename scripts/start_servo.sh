#!/usr/bin/env bash
set -eo pipefail

WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
SERVO_SERVICE="${SERVO_SERVICE:-/servo_node/start_servo}"
SERVO_WAIT_TIMEOUT="${SERVO_WAIT_TIMEOUT:-15s}"

source /opt/ros/humble/setup.bash
source "$WORKSPACE/install/setup.bash"

echo "Waiting up to $SERVO_WAIT_TIMEOUT for $SERVO_SERVICE ..."
if ! timeout "$SERVO_WAIT_TIMEOUT" bash -c \
  "until ros2 service list | grep -qx '$SERVO_SERVICE'; do sleep 0.5; done"; then
  echo "Servo service not available: $SERVO_SERVICE" >&2
  echo "Start the MoveIt Servo launch first, then rerun this script." >&2
  exit 1
fi

ros2 service call "$SERVO_SERVICE" std_srvs/srv/Trigger "{}"
