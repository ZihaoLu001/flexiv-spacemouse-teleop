#!/usr/bin/env bash
set -eo pipefail

# Patterns for every process this repo's scripts can start.
PATTERNS=(
  'ros2 launch flexiv_bringup'
  'ros2 launch flexiv_spacemouse_teleop'
  '/opt/ros/humble/lib/controller_manager/spawner'
  '/opt/ros/humble/lib/controller_manager/ros2_control_node'
  '/opt/ros/humble/lib/moveit_servo/servo_node_main'
  '/opt/ros/humble/lib/moveit_ros_move_group/move_group'
  '/opt/ros/humble/lib/joint_state_publisher/joint_state_publisher'
  '/opt/ros/humble/lib/robot_state_publisher/robot_state_publisher'
  '/opt/ros/humble/lib/spacenav/spacenav_node'
  '/opt/ros/humble/lib/v4l2_camera/v4l2_camera_node'
  'lib/flexiv_gripper/flexiv_gripper_node'
  'lib/flexiv_spacemouse_teleop/spacemouse_to_servo'
  'lib/flexiv_spacemouse_teleop/spacemouse_gn01'
)
# Patterns are anchored to installed executable paths so pkill -f can never
# match an editor or pager that merely has a source file name on its command
# line.

any_alive() {
  for p in "${PATTERNS[@]}"; do
    if pgrep -f "$p" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

signal_all() {
  local sig="$1"
  for p in "${PATTERNS[@]}"; do
    pkill "-$sig" -f "$p" 2>/dev/null || true
  done
}

wait_for_exit() {
  local timeout="$1"
  local waited=0
  while any_alive && [ "$waited" -lt "$timeout" ]; do
    sleep 1
    waited=$((waited + 1))
  done
  ! any_alive
}

if ! any_alive; then
  echo "No ROS teleop stack processes found."
  exit 0
fi

echo "Stopping ROS teleop stack (SIGINT)..."
signal_all INT
if wait_for_exit 8; then
  echo "ROS teleop stack stopped."
  exit 0
fi

echo "Some processes survived SIGINT; escalating to SIGTERM..."
signal_all TERM
if wait_for_exit 5; then
  echo "ROS teleop stack stopped."
  exit 0
fi

echo "Some processes survived SIGTERM; escalating to SIGKILL..."
signal_all KILL
sleep 1
if any_alive; then
  echo "FAILED to stop the following processes:" >&2
  for p in "${PATTERNS[@]}"; do
    pgrep -af "$p" 2>/dev/null || true
  done >&2
  exit 1
fi
echo "ROS teleop stack stopped (killed)."
