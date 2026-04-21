# Safety Checklist

Use this checklist before any real-robot teleoperation session.

## Before Launch

- Emergency stop is reachable.
- The workspace is clear of people, cables, cameras, and fragile objects.
- The robot is in the expected Remote Mode.
- The owner machine can ping the robot.
- No stale ROS control processes are running.
- SpaceMouse motion has been tested in fake hardware.
- The SpaceMouse deadman button behavior has been tested: hold button `0` to
  move, release it to command zero twist.
- Speed scales are conservative.
- A second person knows the robot is about to move if the lab requires it.

## During Operation

- Keep one hand near the emergency stop.
- Keep the SpaceMouse deadman button released unless you intend to move.
- Start with small SpaceMouse deflections.
- Verify each translation axis before using rotation.
- Verify gripper buttons with no object before grasping.
- Stop if MoveIt Servo reports persistent singularity, collision, or stale-state warnings.

## After Operation

- Stop recording.
- Dry-run `scripts/restore_start_state.sh "$STATE_FILE"` before executing a
  return-to-start motion.
- Stop teleop launch processes.
- Save ROS logs if there was an anomaly.
- Return the robot to a safe pose according to lab policy.

## Limits of This Package

The bridge clamps commands and zeroes stale input or missing deadman input. It
does not enforce lab workspace boundaries, human detection, task-level
constraints, or force limits. Those remain the responsibility of the robot
controller, lab procedures, and operator.
