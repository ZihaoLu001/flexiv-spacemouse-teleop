#!/usr/bin/env bash
# One-command SpaceMouse teleoperation.
#
#   scripts/teleop.sh                                  fake hardware (no robot needed)
#   ROBOT_SN=Rizon4s-062626 scripts/teleop.sh --real   real robot
#
# Starts the whole stack (flexiv_ros2 + MoveIt Servo + spacenav + bridges),
# enables Servo, and tears everything down again on Ctrl-C.
#
# Options:
#   --real           drive the real robot (requires ROBOT_SN)
#   --fake           use fake hardware (default)
#   --no-gripper     skip the gripper model and button bridge
#   --camera         also start the ZED RGB camera stream
#   --record         also record a demo rosbag (implies robot topics must exist)
#   --keep-stack     leave the robot stack running when this script exits
set -eo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
RIZON_TYPE="${RIZON_TYPE:-Rizon4s}"
SERVO_WAIT_TIMEOUT_S="${SERVO_WAIT_TIMEOUT_S:-90}"
LOG_DIR="${LOG_DIR:-$HOME/teleop_logs/$(date +%Y%m%d_%H%M%S)}"

MODE=fake
GRIPPER=true
CAMERA=false
RECORD=false
KEEP_STACK=false

for arg in "$@"; do
  case "$arg" in
    --real) MODE=real ;;
    --fake) MODE=fake ;;
    --no-gripper) GRIPPER=false ;;
    --camera) CAMERA=true ;;
    --record) RECORD=true ;;
    --keep-stack) KEEP_STACK=true ;;
    -h|--help)
      sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown option: $arg (see --help)" >&2
      exit 2
      ;;
  esac
done

say() { printf '\033[1;36m[teleop]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[teleop]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- preflight
[ -f /opt/ros/humble/setup.bash ] || die "ROS 2 Humble not found. Run scripts/install_owner_machine_ubuntu22_humble.sh first."
# shellcheck disable=SC1091
source /opt/ros/humble/setup.bash
[ -f "$WORKSPACE/install/setup.bash" ] || die "Workspace not built. Run scripts/build_workspace.sh first."
# shellcheck disable=SC1090
source "$WORKSPACE/install/setup.bash"

if [ "$MODE" = "real" ]; then
  if [ -z "${ROBOT_SN:-}" ] || [ "$ROBOT_SN" = "Rizon4s-123456" ]; then
    die "Real mode needs an explicit ROBOT_SN. Example: ROBOT_SN=Rizon4s-062626 $0 --real"
  fi
else
  ROBOT_SN="${ROBOT_SN:-Rizon4s-123456}"
fi

existing="$(pgrep -af 'ros2 launch flexiv_bringup|servo_node_main|ros2_control_node' \
  | grep -v -E 'pgrep -af|teleop\.sh|bash -c|bash -lc|ssh ' || true)"
[ -z "$existing" ] || die "A Flexiv/Servo stack is already running. Stop it first: scripts/stop_ros_stack.sh"$'\n'"$existing"

if ! systemctl is-active --quiet spacenavd; then
  say "spacenavd is not running; trying to start it (may prompt for sudo)..."
  sudo systemctl start spacenavd || die "spacenavd could not be started; SpaceMouse input will not work."
fi

SERVO_CONFIG="$WORKSPACE/src/flexiv_ros2/flexiv_moveit_config/config/rizon_moveit_servo_config.yaml"
if ! "$REPO_DIR/scripts/apply_servo_config.sh" --check >/dev/null 2>&1; then
  say "Servo config in flexiv_ros2 differs from the repo-managed version; installing it..."
  "$REPO_DIR/scripts/apply_servo_config.sh"
fi
if grep -q "grav_tcp" "$SERVO_CONFIG" && [ "$GRIPPER" != "true" ]; then
  die "Servo config uses the grav_tcp frame which needs the gripper model; drop --no-gripper or change ee_frame_name."
fi

mkdir -p "$LOG_DIR"
say "Logs: $LOG_DIR"

# ------------------------------------------------------------------ cleanup
# Every component we start runs in its own process group (setsid), and cleanup
# signals exactly those groups. We deliberately do NOT pattern-kill by process
# name here: other projects on the machine may legitimately run their own
# camera or ROS nodes (scripts/stop_ros_stack.sh remains the explicit big
# hammer for a stuck stack).
STACK_PID=""
CAMERA_PID=""
RECORD_PID=""
BRIDGE_PID=""

kill_group() { # pid, signal
  [ -n "$1" ] || return 0
  kill "-$2" "-$1" 2>/dev/null || kill "-$2" "$1" 2>/dev/null || true
}

group_alive() {
  [ -n "$1" ] && kill -0 "$1" 2>/dev/null
}

cleanup() {
  trap - INT TERM EXIT
  echo
  for pid in "$RECORD_PID" "$CAMERA_PID" "$BRIDGE_PID"; do
    kill_group "$pid" INT
  done
  if [ "$KEEP_STACK" = "true" ]; then
    say "Leaving the robot stack running (--keep-stack). Stop it later with scripts/stop_ros_stack.sh"
  else
    say "Shutting down the ROS stack..."
    kill_group "$STACK_PID" INT
  fi
  waited=0
  while [ "$waited" -lt 10 ]; do
    group_alive "$STACK_PID" || group_alive "$BRIDGE_PID" || break
    sleep 1
    waited=$((waited + 1))
  done
  for pid in "$RECORD_PID" "$CAMERA_PID" "$BRIDGE_PID"; do
    kill_group "$pid" TERM
  done
  if [ "$KEEP_STACK" != "true" ] && group_alive "$STACK_PID"; then
    kill_group "$STACK_PID" TERM
    sleep 2
    if group_alive "$STACK_PID"; then
      say "Stack did not exit cleanly; run scripts/stop_ros_stack.sh if processes linger."
    fi
  fi
  say "Done."
}
trap cleanup INT TERM EXIT

# -------------------------------------------------------------- robot stack
if [ "$MODE" = "real" ]; then
  say "Starting REAL robot stack (SN=$ROBOT_SN, gripper=$GRIPPER)..."
  ROBOT_SN="$ROBOT_SN" RIZON_TYPE="$RIZON_TYPE" LOAD_GRIPPER="$GRIPPER" \
    setsid "$REPO_DIR/scripts/run_real_moveit_servo.sh" >"$LOG_DIR/stack.log" 2>&1 &
else
  say "Starting FAKE robot stack (no hardware needed)..."
  ROBOT_SN="$ROBOT_SN" RIZON_TYPE="$RIZON_TYPE" LOAD_GRIPPER="$GRIPPER" \
    setsid "$REPO_DIR/scripts/run_fake_moveit_servo.sh" >"$LOG_DIR/stack.log" 2>&1 &
fi
STACK_PID=$!

say "Waiting for MoveIt Servo (up to ${SERVO_WAIT_TIMEOUT_S}s)..."
waited=0
until ros2 service list 2>/dev/null | grep -qx /servo_node/start_servo; do
  if ! kill -0 "$STACK_PID" 2>/dev/null; then
    echo "----- last 30 lines of $LOG_DIR/stack.log -----" >&2
    tail -n 30 "$LOG_DIR/stack.log" >&2 || true
    die "Robot stack exited during startup; see $LOG_DIR/stack.log"
  fi
  sleep 1
  waited=$((waited + 1))
  [ "$waited" -lt "$SERVO_WAIT_TIMEOUT_S" ] || die "Servo service did not appear within ${SERVO_WAIT_TIMEOUT_S}s; see $LOG_DIR/stack.log"
done

say "Enabling Servo..."
ros2 service call /servo_node/start_servo std_srvs/srv/Trigger "{}" >/dev/null

# ------------------------------------------------------------------- extras
if [ "$CAMERA" = "true" ]; then
  say "Starting ZED RGB camera..."
  setsid "$REPO_DIR/scripts/run_zed_rgb_camera.sh" >"$LOG_DIR/camera.log" 2>&1 &
  CAMERA_PID=$!
fi

if [ "$RECORD" = "true" ]; then
  say "Starting demo recording..."
  ROBOT_SN="$ROBOT_SN" setsid "$REPO_DIR/scripts/record_demo.sh" >"$LOG_DIR/record.log" 2>&1 &
  RECORD_PID=$!
fi

# ------------------------------------------------------------------- bridge
say "Teleoperation is live."
say "  HOLD button 0 (left) as the deadman to move the arm."
[ "$GRIPPER" = "true" ] && say "  PRESS button 1 (right) to toggle the gripper."
say "  Ctrl-C stops teleop and shuts the whole stack down."
echo

setsid ros2 launch flexiv_spacemouse_teleop spacemouse_teleop.launch.py \
  enable_gripper:="$GRIPPER" >"$LOG_DIR/bridge.log" 2>&1 &
BRIDGE_PID=$!
tail -f "$LOG_DIR/bridge.log" --pid="$BRIDGE_PID" &
wait "$BRIDGE_PID"
