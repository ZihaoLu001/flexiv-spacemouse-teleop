#!/usr/bin/env bash
set -eo pipefail

WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
STATE_FILE="${STATE_FILE:-${1:-}}"

if [ -z "$STATE_FILE" ]; then
  echo "Usage: $0 <start_joint_state.json> [--execute]" >&2
  echo "Tip: run scripts/save_start_state.sh before teleoperation starts." >&2
  exit 2
fi

shift || true

source /opt/ros/humble/setup.bash
source "$WORKSPACE/install/setup.bash"

ros2 run flexiv_spacemouse_teleop return_to_joint_state "$STATE_FILE" "$@"
