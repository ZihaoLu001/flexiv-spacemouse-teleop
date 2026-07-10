#!/usr/bin/env bash
set -eo pipefail

WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
mkdir -p "$WORKSPACE/src"
cd "$WORKSPACE/src"

if [ ! -d flexiv_ros2 ]; then
  git clone --recurse-submodules --branch humble-v1.7 --depth 1 \
    https://github.com/flexivrobotics/flexiv_ros2.git
else
  cd flexiv_ros2
  # Refuse to clobber local modifications: the only sanctioned local changes
  # are the files installed by scripts/apply_servo_config.sh.
  dirty="$(git status --porcelain | grep -vE 'rizon_moveit_servo_config\.yaml|grav\.srdf\.xacro|\.pre_apply\.bak' || true)"
  if [ -n "$dirty" ]; then
    echo "Refusing to update: flexiv_ros2 has unexpected local modifications:" >&2
    echo "$dirty" >&2
    echo "Commit them somewhere or restore the pristine tree first." >&2
    exit 2
  fi
  git fetch --tags origin humble-v1.7
  git checkout humble-v1.7
  git submodule update --init --recursive
fi

echo "flexiv_ros2 humble-v1.7 is ready under $WORKSPACE/src/flexiv_ros2"
echo "Now install the repo-managed Servo config: scripts/apply_servo_config.sh"
