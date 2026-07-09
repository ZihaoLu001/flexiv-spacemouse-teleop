#!/usr/bin/env bash
set -eo pipefail

ROBOT_IP="${ROBOT_IP:-192.168.100.1}"
WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

issues=0

section() {
  printf "\n== %s ==\n" "$1"
}

fail() {
  echo "PROBLEM: $1" >&2
  issues=$((issues + 1))
}

section "OS"
lsb_release -a 2>/dev/null || cat /etc/os-release
uname -a

section "ROS"
if [ -f /opt/ros/humble/setup.bash ]; then
  # shellcheck disable=SC1091
  source /opt/ros/humble/setup.bash
  command -v ros2
  ros2 --help >/dev/null && echo "ROS 2 Humble CLI OK"
else
  fail "Missing /opt/ros/humble/setup.bash"
fi

section "Workspace"
if [ -f "$WORKSPACE/install/setup.bash" ]; then
  # shellcheck disable=SC1090
  source "$WORKSPACE/install/setup.bash"
  for pkg in flexiv_bringup flexiv_spacemouse_teleop flexiv_msgs; do
    if ros2 pkg list | grep -qx "$pkg"; then
      echo "$pkg OK"
    else
      fail "workspace package missing: $pkg (run scripts/build_workspace.sh)"
    fi
  done
else
  fail "Workspace install not found: $WORKSPACE/install/setup.bash"
fi

section "ROS Packages"
if command -v ros2 >/dev/null; then
  for pkg in spacenav moveit_servo v4l2_camera; do
    if ros2 pkg list | grep -qx "$pkg"; then
      echo "$pkg OK"
    else
      fail "ROS package missing: $pkg (apt install ros-humble-${pkg//_/-})"
    fi
  done
fi

section "Flexiv RDK (Python)"
if python3 -c "import flexivrdk" 2>/dev/null; then
  rdk_version="$(pip3 show flexivrdk 2>/dev/null | awk '/^Version:/{print $2}')"
  echo "flexivrdk ${rdk_version:-unknown} OK"
  case "$rdk_version" in
    1.7.*) ;;
    *) fail "flexivrdk $rdk_version may not match robot software v1.7; pin flexivrdk==1.7.0" ;;
  esac
else
  fail "flexivrdk Python package missing (pip3 install 'flexivrdk==1.7.0'); needed by scripts/init_gn01_once.py"
fi

section "Servo Config"
SERVO_CONFIG="$WORKSPACE/src/flexiv_ros2/flexiv_moveit_config/config/rizon_moveit_servo_config.yaml"
if [ -f "$SERVO_CONFIG" ]; then
  if ! grep -Eq '^check_collisions:[[:space:]]*true' "$SERVO_CONFIG"; then
    fail "Servo collision checking is DISABLED in $SERVO_CONFIG"
  else
    echo "check_collisions: true OK"
  fi
  timeout_val="$(awk '/^incoming_command_timeout:/{print $2}' "$SERVO_CONFIG")"
  if [ "$timeout_val" = "0" ] || [ -z "$timeout_val" ]; then
    fail "incoming_command_timeout must be > 0 in $SERVO_CONFIG (got '${timeout_val:-unset}')"
  else
    echo "incoming_command_timeout: $timeout_val OK"
  fi
  if [ -x "$REPO_DIR/scripts/apply_servo_config.sh" ]; then
    if "$REPO_DIR/scripts/apply_servo_config.sh" --check >/dev/null 2>&1; then
      echo "Servo config matches the repo-managed version OK"
    else
      fail "Servo config differs from config/rizon_moveit_servo_config.lab.yaml (run scripts/apply_servo_config.sh)"
    fi
  fi
else
  fail "Servo config not found: $SERVO_CONFIG (run scripts/fetch_flexiv_ros2_humble_v1_7.sh)"
fi

section "Input Device"
systemctl is-active spacenavd || fail "spacenavd is not active (sudo systemctl enable --now spacenavd)"
lsusb | grep -Ei '3dconnexion|spacemouse' || fail "SpaceMouse USB device not detected by lsusb"

section "Camera"
if lsusb | grep -Ei 'stereolabs|zed' >/dev/null; then
  lsusb | grep -Ei 'stereolabs|zed'
else
  echo "ZED USB device not detected by lsusb (OK if you are not recording video)"
fi
lsusb -t | grep -E '5000M|10000M|20000M' || echo "No SuperSpeed USB camera path detected"
ls -l /dev/video* 2>/dev/null || echo "No /dev/video* devices detected"
if command -v v4l2-ctl >/dev/null; then
  v4l2-ctl --list-devices || true
else
  echo "v4l2-ctl missing; install v4l-utils"
fi

section "Robot Network"
ip -br addr
ip route get "$ROBOT_IP" || true
if ping -c 1 -W 1 "$ROBOT_IP" >/dev/null; then
  echo "Robot ping OK: $ROBOT_IP"
else
  echo "Robot ping failed: $ROBOT_IP (OK if the robot is off or you only run fake hardware)"
fi

section "ROS Processes"
ps -eo pid,cmd | grep -E '[s]ervo_node_main|[m]ove_group|[r]os2_control_node|[s]pacenav_node|[s]pacemouse_to_servo|[s]pacemouse_gn01' || echo "(none running)"

section "Summary"
if [ "$issues" -eq 0 ]; then
  echo "All checks passed."
else
  echo "$issues problem(s) found — see PROBLEM lines above." >&2
  exit 1
fi
