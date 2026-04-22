#!/usr/bin/env bash
set -eo pipefail

WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
STATE_FILE="${STATE_FILE:-${1:-}}"
STOP_SERVO_BEFORE_RESTORE="${STOP_SERVO_BEFORE_RESTORE:-true}"
SERVO_STOP_SERVICE="${SERVO_STOP_SERVICE:-/servo_node/stop_servo}"

if [ -z "$STATE_FILE" ]; then
  echo "Usage: $0 <start_joint_state.json> [--execute]" >&2
  echo "Tip: run scripts/save_start_state.sh before teleoperation starts." >&2
  exit 2
fi

shift || true

source /opt/ros/humble/setup.bash
source "$WORKSPACE/install/setup.bash"

if [ "$STOP_SERVO_BEFORE_RESTORE" = "true" ]; then
  if ros2 service list | grep -Fxq "$SERVO_STOP_SERVICE"; then
    echo "Stopping Servo before return-to-start so it cannot overwrite the trajectory..."
    ros2 service call "$SERVO_STOP_SERVICE" std_srvs/srv/Trigger "{}" || true
    sleep 0.5
  else
    echo "Servo stop service $SERVO_STOP_SERVICE not found; continuing with restore." >&2
  fi
fi

ros2 run flexiv_spacemouse_teleop return_to_joint_state "$STATE_FILE" "$@"
