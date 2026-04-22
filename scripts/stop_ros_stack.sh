#!/usr/bin/env bash
set -eo pipefail

pkill -INT -f 'ros2 launch flexiv_bringup' || true
pkill -INT -f 'ros2 launch flexiv_spacemouse_teleop' || true
sleep 2
pkill -TERM -f '/opt/ros/humble/lib/controller_manager/spawner' || true
pkill -TERM -f '/opt/ros/humble/lib/controller_manager/ros2_control_node' || true
pkill -TERM -f '/opt/ros/humble/lib/moveit_servo/servo_node_main' || true
pkill -TERM -f '/opt/ros/humble/lib/moveit_ros_move_group/move_group' || true
pkill -TERM -f '/opt/ros/humble/lib/joint_state_publisher/joint_state_publisher' || true
pkill -TERM -f '/opt/ros/humble/lib/robot_state_publisher/robot_state_publisher' || true
pkill -TERM -f '/opt/ros/humble/lib/spacenav/spacenav_node' || true
pkill -TERM -f '/opt/ros/humble/lib/v4l2_camera/v4l2_camera_node' || true
pkill -TERM -f 'spacemouse_to_servo' || true
pkill -TERM -f 'spacemouse_gn01' || true

echo "Requested ROS teleop stack shutdown."
