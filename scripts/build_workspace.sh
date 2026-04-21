#!/usr/bin/env bash
set -eo pipefail

WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
RDK_INSTALL="${RDK_INSTALL:-$HOME/rdk_install}"
JOBS="${JOBS:-$(nproc)}"

if [ "$JOBS" -gt 8 ]; then
  JOBS=8
fi

source /opt/ros/humble/setup.bash

cd "$WORKSPACE"
rosdep install --from-paths src --ignore-src --rosdistro humble -r -y

mkdir -p "$RDK_INSTALL"
cd "$WORKSPACE/src/flexiv_ros2/flexiv_hardware/rdk/thirdparty"
bash build_and_install_dependencies.sh "$RDK_INSTALL" "$JOBS"

cd "$WORKSPACE/src/flexiv_ros2/flexiv_hardware/rdk"
rm -rf build
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX="$RDK_INSTALL"
cmake --build . --target install --config Release -j"$JOBS"

cd "$WORKSPACE"
colcon build --symlink-install --cmake-args -DCMAKE_PREFIX_PATH="$RDK_INSTALL"

echo "Build complete. Source $WORKSPACE/install/setup.bash before running."
