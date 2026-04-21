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
export ROBOT_SN=Rizon4s-123456
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
scripts/run_spacemouse_bridge.sh
```

## Axis Tuning

If an axis feels reversed, edit `config/spacemouse_teleop.yaml`:

```yaml
sign_lx: 1.0
sign_ly: -1.0
sign_lz: 1.0
sign_ax: 1.0
sign_ay: -1.0
sign_az: 1.0
```

If the robot moves too quickly, reduce:

```yaml
linear_scale: 0.20
angular_scale: 0.40
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
