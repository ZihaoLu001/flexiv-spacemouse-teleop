# Safety Checklist

Use this checklist before any real-robot teleoperation session.

## Before Launch

- Emergency stop is reachable.
- The workspace is clear of people, cables, cameras, and fragile objects.
- The robot is in the expected Remote Mode.
- The owner machine can ping the robot.
- No stale ROS control processes are running (`teleop.sh` and the run scripts
  refuse to start on top of an existing stack; `scripts/stop_ros_stack.sh`
  cleans up).
- `scripts/doctor.sh` passes (it verifies, among other things, the Servo
  config safety keys and the `flexivrdk` version pairing).
- SpaceMouse motion has been tested in fake hardware (`scripts/teleop.sh`
  without `--real`).
- The SpaceMouse deadman button behavior has been tested: hold button `0` to
  move, release it to command zero twist.
- Speed scales are conservative.
- A second person knows the robot is about to move if the lab requires it.

## During Operation

- Keep one hand near the emergency stop.
- Keep the SpaceMouse deadman button released unless you intend to move.
- Start with small SpaceMouse deflections.
- Verify each translation axis before using rotation.
- Verify the gripper button with no object before grasping.
- Stop if MoveIt Servo reports persistent singularity, collision, or
  stale-state warnings.

## Emergency Stop (E-stop) Recovery

After the E-stop has been pressed, recover in this order:

1. Remove the cause. Inspect the scene before anything else.
2. Release the E-stop.
3. Clear the robot fault — in Flexiv Elements, or via RDK `ClearFault()`
   (`scripts/init_gn01_once.py` does this as part of its sequence).
4. **Restart the ROS stack.** The flexiv_ros2 v1.7 driver silently drops
   commands after a fault; a stack that "looks alive" after an E-stop is not
   trustworthy. `Ctrl-C` the old `teleop.sh` (or run
   `scripts/stop_ros_stack.sh`) and start it again.
5. Do **not** run `scripts/restore_start_state.sh --execute` after an E-stop
   or collision without inspecting the scene first. The return-to-start motion
   is a joint-space interpolation with no collision checking (see below).

## Collision Checking

`check_collisions: true` is the repo-managed default in
`config/rizon_moveit_servo_config.lab.yaml` (it matches the upstream
flexiv_ros2 default). `scripts/doctor.sh` and
`scripts/run_real_moveit_servo.sh` verify it; `scripts/teleop.sh` reinstalls
the repo-managed config if it drifted.

Do not disable it. It was once hand-disabled on the lab machine "temporarily
for a gripper demo", which silently removed all self-collision deceleration.
The false alarm behind that decision (closed GN01 finger tips permanently
within the proximity threshold) is fixed by the repo-managed gripper SRDF
(`config/grav.srdf.lab.xacro`, installed alongside the Servo config). If
collision checking falsely triggers again, extend the SRDF collision matrix
instead of turning the feature off. Any intentional change belongs in the
repo-managed files (installed via `scripts/apply_servo_config.sh`) so it is
recorded and reviewable.

## Return-to-Start Motions

`scripts/restore_start_state.sh` / `return_to_joint_state`:

- Dry-run by default; `--execute` is required to move the robot.
- Stops Servo first, so idle teleop commands cannot overwrite the trajectory.
- Commands a direct joint-space interpolation with **no collision checking**.
  Visually confirm the straight-line joint path is clear of obstacles before
  `--execute`.
- Refuses per-joint deltas above 0.7 rad and estimated peak joint speeds above
  0.25 rad/s (the trajectory's peak speed is ~1.5x the average) unless
  `--force` is passed after inspecting the robot.
- `Ctrl-C` during execution cancels the goal rather than leaving the
  controller running the trajectory.

## After Operation

- Stop recording.
- Dry-run `scripts/restore_start_state.sh "$STATE_FILE"` before executing a
  return-to-start motion.
- Stop teleop with `Ctrl-C` (`teleop.sh` shuts the stack down) or
  `scripts/stop_ros_stack.sh`.
- Save ROS logs (`~/teleop_logs/<timestamp>/`) if there was an anomaly.
- Return the robot to a safe pose according to lab policy.

## Limits of This Package

The bridge clamps commands (`clamp_abs: 0.62` in the default YAML) and zeroes
stale input or missing deadman input; Servo decelerates near singularities and
checks collisions. Note that while the bridge is running it publishes zero
twists even when idle (`publish_when_idle: true`), so Servo stays active,
holds position, and overrides any parallel motion command — stop Servo before
commanding the arm from anywhere else.

The package does not enforce lab workspace boundaries, human detection,
task-level constraints, or force limits. Those remain the responsibility of
the robot controller, lab procedures, and operator.
