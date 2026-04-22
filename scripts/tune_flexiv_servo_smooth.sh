#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
SERVO_CONFIG="${SERVO_CONFIG:-$WORKSPACE/src/flexiv_ros2/flexiv_moveit_config/config/rizon_moveit_servo_config.yaml}"
PUBLISH_PERIOD="${PUBLISH_PERIOD:-0.02}"
SMOOTHING_PLUGIN="${SMOOTHING_PLUGIN:-online_signal_smoothing::ButterworthFilterPlugin}"
JOINT_TOPIC="${JOINT_TOPIC:-/flexiv_arm/joint_states}"

if [ ! -f "$SERVO_CONFIG" ]; then
  echo "Servo config not found: $SERVO_CONFIG" >&2
  exit 2
fi

if [ "$SMOOTHING_PLUGIN" != "online_signal_smoothing::ButterworthFilterPlugin" ]; then
  if ! grep -R "$SMOOTHING_PLUGIN" /opt/ros/humble/share /opt/ros/humble/lib "$WORKSPACE/install" >/dev/null 2>&1; then
    echo "Requested smoothing plugin is not installed: $SMOOTHING_PLUGIN" >&2
    echo "Keeping the installed-safe Butterworth plugin is recommended on this Humble system." >&2
    exit 2
  fi
fi

backup="${SERVO_CONFIG}.$(date +%Y%m%d_%H%M%S).bak"
cp "$SERVO_CONFIG" "$backup"

sed -i -E "s|^([[:space:]]*publish_period:[[:space:]]*).*|\\1${PUBLISH_PERIOD}|" "$SERVO_CONFIG"
sed -i -E "s|^([[:space:]]*smoothing_filter_plugin_name:[[:space:]]*).*|\\1\"${SMOOTHING_PLUGIN}\"|" "$SERVO_CONFIG"
sed -i -E "s|^([[:space:]]*joint_topic:[[:space:]]*).*|\\1${JOINT_TOPIC}|" "$SERVO_CONFIG"

echo "Backed up Servo config to: $backup"
echo "Updated Servo config:"
grep -nE 'publish_period|low_latency_mode|smoothing_filter_plugin_name|joint_topic' "$SERVO_CONFIG"
