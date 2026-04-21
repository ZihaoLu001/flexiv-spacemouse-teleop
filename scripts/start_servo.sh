#!/usr/bin/env bash
set -eo pipefail

WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
source /opt/ros/humble/setup.bash
source "$WORKSPACE/install/setup.bash"

ros2 service call /servo_node/start_servo std_srvs/srv/Trigger "{}"
