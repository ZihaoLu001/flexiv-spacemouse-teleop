# Operator Manual

This manual is for running SpaceMouse teleoperation on a Flexiv Rizon arm
through ROS 2 Humble and MoveIt Servo. The normal entry point is
`scripts/teleop.sh`; the per-piece multi-terminal procedure is kept as an
appendix for debugging.

## Required Hardware

- Flexiv Rizon arm with RDK enabled (robot software v1.7)
- Ubuntu 22.04 owner machine on the robot network
- 3Dconnexion SpaceMouse connected to the owner machine
- Flexiv-GN01 gripper if using button-controlled grasping

## Preflight

Run the environment check first; it exits non-zero and prints `PROBLEM:` lines
when something is wrong:

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
scripts/doctor.sh
```

For real hardware also confirm:

1. The robot workspace is clear and the emergency stop is reachable.
2. The robot is in Remote Mode and RDK is enabled.
3. Network: `ping 192.168.100.1` succeeds (direct connection to the Flexiv
   general port).
4. You have read the [safety checklist](SAFETY.md).

## Fake Hardware (Recommended First)

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
scripts/teleop.sh
```

The script starts the fake-hardware flexiv_ros2 stack, MoveIt Servo,
`spacenav_node`, and both bridges, enables Servo, and prints when
teleoperation is live. Verify the pipeline in another terminal:

```bash
ros2 topic echo /servo_node/delta_twist_cmds
```

Hold SpaceMouse button `0` and move the puck; the `TwistStamped` values should
change. Release the button; they should return to zero. `Ctrl-C` in the teleop
terminal shuts the whole stack down.

## One-Time Gripper Initialization

After a controller power-cycle, the GN01 must be initialized once. This must
run while the ROS stack is **stopped** — the robot accepts a single RDK
connection and the flexiv_ros2 hardware interface holds it while running. It
requires the `flexivrdk==1.7.0` pip package (installed by the install script)
and an explicit serial number:

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
scripts/stop_ros_stack.sh
ROBOT_SN=Rizon4s-062626 python3 scripts/init_gn01_once.py
```

The script follows the official RDK sequence (fault check, enable, gripper
enable, `Tool.Switch`, init, 10 s wait) and refuses placeholder serial numbers
or a running ROS stack.

## Real Hardware Procedure

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
ROBOT_SN=Rizon4s-062626 scripts/teleop.sh --real
```

For the first real run, verify the arm axes gently before using the gripper
button. Note that `--no-gripper` does NOT work with the default configuration:
the repo-managed Servo config uses the `grav_tcp` end-effector frame, which
only exists when the gripper **model** is loaded, so `teleop.sh --no-gripper`
refuses to start (by design). To run genuinely gripper-less hardware, change
`ee_frame_name` in `config/rizon_moveit_servo_config.lab.yaml` back to the
flange, rerun `scripts/apply_servo_config.sh`, and re-calibrate the `sign_*`
values.

Controls:

- **Button 0 (left) is the deadman.** Hold it to command motion; release it
  immediately if anything feels wrong — the bridge then publishes zero twist.
- **Button 1 (right) toggles the gripper** on the rising edge (press, not
  hold): 0.09 m open / 0.01 m close. The internal open/closed state only
  advances once the goal is accepted by the gripper action server, and
  rejected or failed goals are logged. The flexiv_ros2 v1.7 gripper server
  ignores `max_effort` and moves the GN01 with internal constants; the
  `max_force` parameter is sent only for forward compatibility.
- **Ctrl-C** stops teleop and shuts the whole stack down (unless
  `--keep-stack`).

Save the return target before moving the arm (see the next section), start with
small deflections, and verify each translation axis before using rotation.
Test the gripper toggle with no object first.

Logs for each run are in `~/teleop_logs/<timestamp>/` (`stack.log` for the
robot stack, `bridge.log` for the bridges).

## Session Save and Restore

Before moving the arm, save the start joint state:

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
STATE_FILE=$(scripts/save_start_state.sh)
echo "$STATE_FILE"
```

At the end of the session, return to it while the robot stack is still
running:

```bash
scripts/restore_start_state.sh "$STATE_FILE"            # dry run
scripts/restore_start_state.sh "$STATE_FILE" --execute  # moves the robot
scripts/stop_ros_stack.sh
```

If your lab uses one fixed home pose, put the saved state path in
`~/teleop_sessions/fixed_home_state.txt`; then the restore commands can omit
the state file.

How restore behaves:

- Without `--execute` it only prints a dry-run summary. It never moves the
  robot without the explicit flag.
- It **stops `/servo_node` first**. The bridge idles by publishing zero twists
  at 50 Hz (`publish_when_idle: true`), so a live Servo would immediately
  overwrite the return trajectory.
- It sends a single `FollowJointTrajectory` goal to
  `/rizon_arm_controller/follow_joint_trajectory` over 8 s by default. This is
  a joint-space interpolation with **no collision checking**: visually confirm
  the straight-line joint path is clear before `--execute`, and never use it
  to recover from a collision or E-stop without inspecting the scene.
- It refuses per-joint deltas above 0.7 rad and estimated **peak** joint
  speeds above 0.25 rad/s (the controller's rest-to-rest spline peaks at
  ~1.5x the average speed) unless you pass `--force` after inspecting the
  robot. Increase `--duration` for a slower return.
- It restores only arm joints matching `joint1`..`joint7` (7 required), not
  gripper joints, objects, cables, or cameras.
- `Ctrl-C` during execution cancels the trajectory goal instead of leaving the
  controller executing it.
- After the action succeeds, it checks `/joint_states` and fails if the final
  joint error exceeds `--goal-tolerance` (0.04 rad default).

## Recording Demonstrations

The simplest way is to let `teleop.sh` handle it:

```bash
ROBOT_SN=Rizon4s-062626 scripts/teleop.sh --real --camera --record
```

Or run the recorder separately once the stack is up. It requires an explicit
`ROBOT_SN` (used to derive robot topic names) and refuses to record topics
that are not advertised, so a wrong SN or dead camera fails loudly instead of
producing silently empty tracks:

```bash
ROBOT_SN=Rizon4s-062626 scripts/record_demo.sh
```

Robot topic names replace the SN's hyphen with an underscore (ROS 2 topic
names cannot contain `-`), e.g. `/Rizon4s_062626/tcp_pose`. Camera modes:

```bash
CAMERA_MODE=raw ROBOT_SN=... scripts/record_demo.sh   # full raw RGB, much larger bags
CAMERA_MODE=none ROBOT_SN=... scripts/record_demo.sh  # proprioception only
```

The default records `/zed2i/image_raw/compressed`. Output goes to
`~/teleop_demos/<timestamp>/rosbag`, with a `README.txt` next to it recording
the SN, topic list, and start time. Stop with `Ctrl-C`.

Check the camera stream with `scripts/check_camera_topics.sh` (the ZED 2i
publishes a 2560x720 side-by-side stereo pair; crop the left half downstream
for a single RGB view).

## Parameter Tuning

All bridge parameters live in `config/spacemouse_teleop.yaml` — the single
source of truth; launch arguments no longer override YAML values. With a
`--symlink-install` build there is nothing to recompile: edit the YAML and
restart the launch / `teleop.sh`.

If an axis feels reversed, flip the matching sign:

```yaml
sign_lx: 1.0
sign_ly: -1.0
sign_lz: -1.0
sign_ax: 1.0
sign_ay: -1.0
sign_az: 1.0
```

These signs are calibrated for commands interpreted in the robot **base**
frame (`robot_link_command_frame` in the repo-managed Servo config).
Re-calibrate them if you change the command frame.

If the robot moves too quickly, reduce:

```yaml
linear_scale: 0.32
linear_y_scale: 0.45
angular_scale: 0.48
smoothing_alpha: 0.35
max_linear_step: 0.025
clamp_abs: 0.62
```

This is the current lab demo profile, tuned after grasp tests showed visible
jitter at higher lateral and angular gains. With Servo's unitless
`scale.linear: 0.4`, `linear_scale: 0.32` maps full deflection to about
0.13 m/s. The bridge clamps every command to `clamp_abs` (0.62 in the YAML;
the node's built-in default is 0.75).

`publish_when_idle: true` (default) keeps zero twists flowing at 50 Hz while
idle so Servo holds position — and keeps ownership of the arm controller. Any
parallel motion command is overridden while the bridge runs; stop Servo before
sending other trajectories (the restore script does this automatically).

Servo-side settings (publish period, frames, collision checking) live in
`config/rizon_moveit_servo_config.lab.yaml`; change them there and re-run
`scripts/apply_servo_config.sh` — never hand-edit the copy inside
`flexiv_ros2`.

## Troubleshooting

Run `scripts/doctor.sh`, check `~/teleop_logs/<timestamp>/stack.log`, then see
[TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Appendix: Manual Multi-Terminal Procedure

For debugging individual pieces, the stack can be started by hand.

Terminal 1 — robot stack + Servo:

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
# fake hardware:
scripts/run_fake_moveit_servo.sh
# or real hardware (LOAD_GRIPPER defaults to true):
ROBOT_SN=Rizon4s-062626 RIZON_TYPE=Rizon4s scripts/run_real_moveit_servo.sh
```

`run_real_moveit_servo.sh` refuses to start without an explicit `ROBOT_SN`,
refuses `LOAD_GRIPPER=false` while the Servo config uses `grav_tcp`, warns if
collision checking is disabled, and refuses to start on top of an existing
stack.

Terminal 2 — enable Servo, save state, start the bridges:

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
scripts/start_servo.sh
STATE_FILE=$(scripts/save_start_state.sh)
scripts/run_spacemouse_bridge.sh enable_gripper:=false   # or enable_gripper:=true
```

Terminal 3 — optional extras:

```bash
scripts/run_zed_rgb_camera.sh
scripts/check_camera_topics.sh
ROBOT_SN=Rizon4s-062626 scripts/record_demo.sh
```

Shutdown:

```bash
scripts/restore_start_state.sh "$STATE_FILE" --execute
scripts/stop_ros_stack.sh
```

`stop_ros_stack.sh` verifies processes actually exit and escalates
INT -> TERM -> KILL, reporting anything it could not stop.
