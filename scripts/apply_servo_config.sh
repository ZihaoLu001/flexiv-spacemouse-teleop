#!/usr/bin/env bash
# Install this repo's versioned MoveIt Servo config into the flexiv_ros2
# checkout (which flexiv_bringup loads by path), replacing the old practice of
# hand-editing or sed-ing the vendor tree.
#
#   scripts/apply_servo_config.sh            install repo config into flexiv_ros2
#   scripts/apply_servo_config.sh --check    exit 0 iff installed == repo config
#   scripts/apply_servo_config.sh --restore  restore the pristine upstream file (git checkout)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
SRC_CONFIG="$REPO_DIR/config/rizon_moveit_servo_config.lab.yaml"
DEST_CONFIG="${SERVO_CONFIG:-$WORKSPACE/src/flexiv_ros2/flexiv_moveit_config/config/rizon_moveit_servo_config.yaml}"
FLEXIV_ROS2_DIR="$(dirname "$(dirname "$(dirname "$DEST_CONFIG")")")"

if [ ! -f "$DEST_CONFIG" ]; then
  echo "Servo config not found: $DEST_CONFIG" >&2
  echo "Fetch flexiv_ros2 first: scripts/fetch_flexiv_ros2_humble_v1_7.sh" >&2
  exit 2
fi

case "${1:-}" in
  --check)
    if cmp -s "$SRC_CONFIG" "$DEST_CONFIG"; then
      echo "Servo config matches $SRC_CONFIG"
    else
      echo "Servo config DIFFERS from the repo-managed version:" >&2
      diff -u "$DEST_CONFIG" "$SRC_CONFIG" >&2 || true
      exit 1
    fi
    ;;
  --restore)
    git -C "$FLEXIV_ROS2_DIR" checkout -- "flexiv_moveit_config/config/$(basename "$DEST_CONFIG")"
    echo "Restored pristine upstream Servo config."
    ;;
  "")
    if ! cmp -s "$SRC_CONFIG" "$DEST_CONFIG"; then
      backup="${DEST_CONFIG}.pre_apply.bak"
      cp "$DEST_CONFIG" "$backup"
      cp "$SRC_CONFIG" "$DEST_CONFIG"
      echo "Installed $SRC_CONFIG"
      echo "  -> $DEST_CONFIG (previous file saved to $backup)"
    else
      echo "Servo config already up to date."
    fi
    echo
    echo "flexiv_ros2 working tree status (should show only the servo config):"
    git -C "$FLEXIV_ROS2_DIR" status --short || true
    echo
    echo "Rebuild + re-launch the stack for the change to take effect"
    echo "(with --symlink-install builds, re-launch is enough)."
    ;;
  *)
    echo "Usage: $0 [--check|--restore]" >&2
    exit 2
    ;;
esac
