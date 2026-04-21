#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
mkdir -p "$WORKSPACE/src"
cd "$WORKSPACE/src"

if [ ! -d flexiv_ros2 ]; then
  git clone --recurse-submodules --branch humble-v1.7 --depth 1 \
    https://github.com/flexivrobotics/flexiv_ros2.git
else
  cd flexiv_ros2
  git fetch --tags origin humble-v1.7
  git checkout humble-v1.7
  git submodule update --init --recursive
fi

echo "flexiv_ros2 humble-v1.7 is ready under $WORKSPACE/src/flexiv_ros2"

