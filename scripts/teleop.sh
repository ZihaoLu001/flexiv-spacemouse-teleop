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
#   --no-gripper     skip the gripper model and button bridge (needs a
#                    flange-frame Servo config; the default uses grav_tcp)
#   --camera         also start the ZED RGB camera stream
#   --record         also record a demo rosbag (camera track only with --camera)
#   --responsive     low-lag bridge profile (tracks the hand ~5x faster; less
#                    filtering, so tremor shows — default profile is smoother)
#   --keep-stack     leave the robot stack running when this script exits
set -eo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="${WORKSPACE:-$HOME/teleop_ws}"
RIZON_TYPE="${RIZON_TYPE:-Rizon4s}"
SERVO_WAIT_TIMEOUT_S="${SERVO_WAIT_TIMEOUT_S:-90}"
TOPIC_WAIT_TIMEOUT_S="${TOPIC_WAIT_TIMEOUT_S:-20}"
LOG_DIR="${LOG_DIR:-$HOME/teleop_logs/$(date +%Y%m%d_%H%M%S)}"

MODE=fake
GRIPPER=true
CAMERA=false
RECORD=false
KEEP_STACK=false
PROFILE=smooth

for arg in "$@"; do
  case "$arg" in
    --real) MODE=real ;;
    --fake) MODE=fake ;;
    --no-gripper) GRIPPER=false ;;
    --camera) CAMERA=true ;;
    --record) RECORD=true ;;
    --keep-stack) KEEP_STACK=true ;;
    --responsive) PROFILE=responsive ;;
    -h|--help)
      sed -n '2,/^set /p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
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

existing="$(pgrep -af 'ros2 launch flexiv_bringup|/moveit_servo/servo_node_main|/controller_manager/ros2_control_node' \
  | grep -v -E 'pgrep -af|teleop\.sh|bash -c|bash -lc|ssh ' || true)"
[ -z "$existing" ] || die "A Flexiv/Servo stack is already running. Stop it first: scripts/stop_ros_stack.sh"$'\n'"$existing"

if ! systemctl is-active --quiet spacenavd; then
  say "spacenavd is not running; trying to start it (may prompt for sudo)..."
  sudo systemctl start spacenavd || die "spacenavd could not be started; SpaceMouse input will not work."
fi

SERVO_CONFIG="${SERVO_CONFIG:-$WORKSPACE/src/flexiv_ros2/flexiv_moveit_config/config/rizon_moveit_servo_config.yaml}"
export SERVO_CONFIG
if ! "$REPO_DIR/scripts/apply_servo_config.sh" --check >/dev/null 2>&1; then
  say "Servo config in flexiv_ros2 differs from the repo-managed version; installing it..."
  "$REPO_DIR/scripts/apply_servo_config.sh"
fi
if grep -Eq '^[[:space:]]*ee_frame_name:.*grav_tcp' "$SERVO_CONFIG" && [ "$GRIPPER" != "true" ]; then
  die "The Servo config's ee_frame_name uses grav_tcp, which needs the gripper model; drop --no-gripper or switch ee_frame_name back to the flange."
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
  wait_list=("$RECORD_PID" "$CAMERA_PID" "$BRIDGE_PID")
  if [ "$KEEP_STACK" = "true" ]; then
    say "Leaving the robot stack running (--keep-stack). Stop it later with scripts/stop_ros_stack.sh"
  else
    say "Shutting down the ROS stack..."
    kill_group "$STACK_PID" INT
    wait_list+=("$STACK_PID")
  fi
  waited=0
  while [ "$waited" -lt 12 ]; do
    still=false
    for pid in "${wait_list[@]}"; do
      group_alive "$pid" && still=true
    done
    [ "$still" = false ] && break
    sleep 1
    waited=$((waited + 1))
  done
  for pid in "${wait_list[@]}"; do
    if group_alive "$pid"; then
      kill_group "$pid" TERM
    fi
  done
  sleep 1
  for pid in "${wait_list[@]}"; do
    if group_alive "$pid"; then
      say "A component did not exit cleanly; run scripts/stop_ros_stack.sh if processes linger."
      break
    fi
  done
  say "Done."
}
trap cleanup INT TERM EXIT

wait_for_topic() { # topic, what
  local waited=0
  until ros2 topic list 2>/dev/null | grep -qx "$1"; do
    sleep 1
    waited=$((waited + 1))
    if [ "$waited" -ge "$TOPIC_WAIT_TIMEOUT_S" ]; then
      return 1
    fi
  done
  return 0
}

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

# ------------------------------------------------------------------- bridge
bridge_args=(enable_gripper:="$GRIPPER")
if [ "$PROFILE" = "responsive" ]; then
  bridge_args+=(config_file:="$REPO_DIR/config/spacemouse_teleop.responsive.yaml")
fi
setsid ros2 launch flexiv_spacemouse_teleop spacemouse_teleop.launch.py \
  "${bridge_args[@]}" >"$LOG_DIR/bridge.log" 2>&1 &
BRIDGE_PID=$!

wait_for_topic /spacenav/twist || die "SpaceMouse bridge did not come up; see $LOG_DIR/bridge.log"

# ------------------------------------------------------------------- extras
if [ "$CAMERA" = "true" ]; then
  say "Starting ZED RGB camera..."
  setsid "$REPO_DIR/scripts/run_zed_rgb_camera.sh" >"$LOG_DIR/camera.log" 2>&1 &
  CAMERA_PID=$!
  wait_for_topic /zed2i/image_raw/compressed \
    || die "Camera stream did not come up; see $LOG_DIR/camera.log"
fi

if [ "$RECORD" = "true" ]; then
  say "Starting demo recording..."
  # Without --camera there is no image stream to record; in fake mode the
  # robot-state topics legitimately do not exist (fake hardware publishes no
  # RDK states), so let record_demo.sh proceed past its topic check for them.
  record_env=(ROBOT_SN="$ROBOT_SN")
  [ "$CAMERA" = "true" ] || record_env+=(CAMERA_MODE=none)
  [ "$MODE" = "fake" ] && record_env+=(ALLOW_MISSING_TOPICS=true)
  env "${record_env[@]}" setsid "$REPO_DIR/scripts/record_demo.sh" >"$LOG_DIR/record.log" 2>&1 &
  RECORD_PID=$!
  sleep 3
  if ! group_alive "$RECORD_PID"; then
    echo "----- $LOG_DIR/record.log -----" >&2
    tail -n 20 "$LOG_DIR/record.log" >&2 || true
    die "Demo recording failed to start; see $LOG_DIR/record.log"
  fi
fi

# ------------------------------------------------------------------- live
say "Teleoperation is live ($PROFILE profile)."
say "  HOLD button 0 (left) as the deadman to move the arm."
[ "$GRIPPER" = "true" ] && say "  PRESS button 1 (right) to toggle the gripper."
[ "$RECORD" = "true" ] && say "  Recording to ~/teleop_demos/ (see $LOG_DIR/record.log)."
say "  Ctrl-C stops teleop and shuts the whole stack down."
echo

tail -f "$LOG_DIR/bridge.log" --pid="$BRIDGE_PID" &
wait "$BRIDGE_PID"
