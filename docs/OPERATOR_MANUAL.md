# Operator Manual

This manual is for running SpaceMouse teleoperation on a Flexiv Rizon arm
through ROS 2 Humble and MoveIt Servo.

## Required Hardware

- Flexiv Rizon arm with RDK enabled
- Ubuntu 22.04 owner machine on the robot network
- 3Dconnexion SpaceMouse connected to the owner machine
- Flexiv-GN01 gripper if using button-controlled grasping

## Network Checklist

The owner machine should be on the robot network. For a direct connection to
the Flexiv general port, the robot is commonly reachable at:

```bash
ping 192.168.100.1
```

If the ping fails, stop and fix networking before launching ROS.

## Fake Hardware Procedure

Terminal 1:

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
export ROBOT_SN=Rizon4s-123456
export RIZON_TYPE=Rizon4s
scripts/run_fake_moveit_servo.sh
```

Terminal 2:

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
scripts/start_servo.sh
scripts/run_spacemouse_bridge.sh enable_gripper:=false
```

Hold SpaceMouse button `0` while moving. Releasing the button sends zero twist
commands.

Terminal 3:

```bash
ros2 topic echo /servo_node/delta_twist_cmds
```

Move the SpaceMouse and verify that `TwistStamped` messages change.

## Real Hardware Procedure

1. Clear the robot workspace.
2. Keep emergency stop reachable.
3. Confirm the robot is in Remote Mode and RDK is enabled.
4. Confirm network:

```bash
ping 192.168.100.1
```

5. Initialize the gripper once after controller power-cycle:

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
export ROBOT_SN=<your robot serial>
export RIZON_TYPE=Rizon4s
python3 scripts/init_gn01_once.py
```

6. Start robot, MoveIt, and Servo:

```bash
scripts/run_real_moveit_servo.sh
```

7. In another terminal, start Servo and SpaceMouse:

```bash
scripts/start_servo.sh
```

8. Save the return target before moving the arm:

```bash
STATE_FILE=$(scripts/save_start_state.sh)
echo "$STATE_FILE"
```

9. Start the SpaceMouse bridge with gripper disabled for the first real run:

```bash
scripts/run_spacemouse_bridge.sh enable_gripper:=false
```

Hold SpaceMouse button `0` while commanding motion. Release it immediately if
anything feels wrong.

After the arm axes are verified, you can restart the bridge with gripper support:

```bash
scripts/run_spacemouse_bridge.sh enable_gripper:=true
```

With gripper support enabled, button `0` remains the arm deadman and button `1`
toggles the GN01 between close and open. Test the toggle with no object first.

## Axis Tuning

If an axis feels reversed, edit `config/spacemouse_teleop.yaml`:

```yaml
sign_lx: 1.0
sign_ly: -1.0
sign_lz: -1.0
sign_ax: 1.0
sign_ay: -1.0
sign_az: 1.0
```

If the robot moves too quickly, reduce:

```yaml
linear_scale: 0.32
linear_y_scale: 0.45
angular_scale: 0.48
```

Rebuild after config edits:

```bash
cd ~/teleop_ws
colcon build --symlink-install --packages-select flexiv_spacemouse_teleop
source install/setup.bash
```

## Recording Demonstrations

Start the ZED 2i fixed RGB stream before recording if image observations are
needed:

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
scripts/run_zed_rgb_camera.sh
```

Verify:

```bash
scripts/check_camera_topics.sh
```

Start a recording terminal after the teleop stack is running:

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
scripts/record_demo.sh
```

The default output path is:

```text
~/teleop_demos/YYYYMMDD_HHMMSS
```

Stop with `Ctrl-C`.

## Restore After Teleoperation

Restore while the robot driver and controller are still running:

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
scripts/restore_start_state.sh "$STATE_FILE"
scripts/restore_start_state.sh "$STATE_FILE" --execute
scripts/stop_ros_stack.sh
```

If your lab uses one fixed home pose, put that saved state path in:

```text
~/teleop_sessions/fixed_home_state.txt
```

Then the restore commands can omit the state file:

```bash
scripts/restore_start_state.sh
scripts/restore_start_state.sh --execute
```

The restore tool sends a `FollowJointTrajectory` goal to
`/rizon_arm_controller/follow_joint_trajectory`. It requires `--execute` before
it moves the robot; without `--execute`, it prints a dry-run summary. By
default it restores only arm joints matching `joint1` through `joint7`, so
gripper joints are not sent to the arm controller. This restores the arm joint
position, not the positions of objects, cables, cameras, or the gripper grasped
object. It also refuses large joint deltas or fast implied return speeds unless
the operator explicitly passes `--force` after inspecting the robot. The restore
script stops `/servo_node` before sending the return trajectory and checks the
final `/joint_states` error after the action reports success.

## Optional Smoothing Tune

If the arm feels slightly steppy during SpaceMouse control, tune the Flexiv
Servo publish period while the robot is at a safe rest pose:

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
scripts/stop_ros_stack.sh
scripts/tune_flexiv_servo_smooth.sh
cd ~/teleop_ws
colcon build --symlink-install --packages-select flexiv_moveit_config
```

This changes the Flexiv MoveIt Servo config from the default
`publish_period: 0.034` to `0.02` and points Servo's `joint_topic` at
`/flexiv_arm/joint_states` instead of the slower `/joint_states` aggregate.
Some MoveIt Servo examples use `0.01`, but this Flexiv owner machine showed
Servo loop overruns at that rate, so `0.02` is the more stable hardware setting
here. It keeps `online_signal_smoothing::ButterworthFilterPlugin`, which is the
smoothing plugin installed in the current Ubuntu 22.04 + ROS 2 Humble
environment.
