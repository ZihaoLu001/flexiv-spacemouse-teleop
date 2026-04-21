#!/usr/bin/env bash
set -eo pipefail

WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
STATE_FILE="${STATE_FILE:-$HOME/teleop_sessions/$(date +%Y%m%d_%H%M%S)/start_joint_state.json}"

source /opt/ros/humble/setup.bash
source "$WORKSPACE/install/setup.bash"

ros2 run flexiv_spacemouse_teleop save_start_state --output "$STATE_FILE" "$@"
