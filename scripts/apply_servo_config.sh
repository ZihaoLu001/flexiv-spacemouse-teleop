#!/usr/bin/env bash
# Install this repo's version-controlled MoveIt Servo config AND the fixed
# GN01 gripper SRDF into the flexiv_ros2 checkout (which flexiv_bringup loads
# by path), replacing the old practice of hand-editing the vendor tree.
#
#   scripts/apply_servo_config.sh            install repo-managed files
#   scripts/apply_servo_config.sh --check    exit 0 iff installed == repo versions
#   scripts/apply_servo_config.sh --restore  restore pristine upstream files (git checkout)
#
# Overrides: WORKSPACE, SERVO_CONFIG (dest yaml path), GRAV_SRDF (dest srdf path).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
SERVO_CONFIG="${SERVO_CONFIG:-$WORKSPACE/src/flexiv_ros2/flexiv_moveit_config/config/rizon_moveit_servo_config.yaml}"
GRAV_SRDF="${GRAV_SRDF:-$WORKSPACE/src/flexiv_ros2/flexiv_moveit_config/srdf/grav.srdf.xacro}"

SRCS=(
  "$REPO_DIR/config/rizon_moveit_servo_config.lab.yaml"
  "$REPO_DIR/config/grav.srdf.lab.xacro"
)
DESTS=(
  "$SERVO_CONFIG"
  "$GRAV_SRDF"
)

FLEXIV_ROS2_DIR="$(dirname "$(dirname "$(dirname "$SERVO_CONFIG")")")"

for dest in "${DESTS[@]}"; do
  if [ ! -f "$dest" ]; then
    echo "Target not found: $dest" >&2
    echo "Fetch flexiv_ros2 first: scripts/fetch_flexiv_ros2_humble_v1_7.sh" >&2
    exit 2
  fi
done

case "${1:-}" in
  --check)
    rc=0
    for i in 0 1; do
      if cmp -s "${SRCS[$i]}" "${DESTS[$i]}"; then
        echo "OK: ${DESTS[$i]} matches ${SRCS[$i]##*/}"
      else
        echo "DIFFERS: ${DESTS[$i]} vs ${SRCS[$i]##*/}:" >&2
        diff -u "${DESTS[$i]}" "${SRCS[$i]}" >&2 || true
        rc=1
      fi
    done
    exit "$rc"
    ;;
  --restore)
    for i in 0 1; do
      rel="${DESTS[$i]#"$FLEXIV_ROS2_DIR"/}"
      git -C "$FLEXIV_ROS2_DIR" checkout -- "$rel"
    done
    echo "Restored pristine upstream Servo config and gripper SRDF."
    ;;
  "")
    changed=false
    for i in 0 1; do
      if ! cmp -s "${SRCS[$i]}" "${DESTS[$i]}"; then
        cp "${DESTS[$i]}" "${DESTS[$i]}.pre_apply.bak"
        cp "${SRCS[$i]}" "${DESTS[$i]}"
        echo "Installed ${SRCS[$i]##*/} -> ${DESTS[$i]}"
        echo "  (previous file saved to ${DESTS[$i]}.pre_apply.bak)"
        changed=true
      fi
    done
    if [ "$changed" = false ]; then
      echo "Servo config and gripper SRDF already up to date."
    fi
    echo
    echo "flexiv_ros2 working tree status (should show only these two files):"
    git -C "$FLEXIV_ROS2_DIR" status --short 2>/dev/null || true
    echo
    echo "Rebuild + re-launch the stack for the change to take effect"
    echo "(with --symlink-install builds, re-launch is enough)."
    ;;
  *)
    echo "Usage: $0 [--check|--restore]" >&2
    exit 2
    ;;
esac
