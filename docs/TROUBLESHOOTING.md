# Troubleshooting

Start with the environment check — it exits non-zero and prints a `PROBLEM:`
line for every issue it finds (missing packages, `flexivrdk` version pairing,
Servo config safety keys, `spacenavd` and SpaceMouse presence, ...), and
reports camera and robot-network status:

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
scripts/doctor.sh
```

Each `teleop.sh` run writes logs to `~/teleop_logs/<timestamp>/`:
`stack.log` (flexiv_ros2 + MoveIt + Servo) and `bridge.log` (spacenav +
bridges), plus `camera.log` / `record.log` when enabled. When `teleop.sh`
fails during startup, it prints the tail of `stack.log`.

## `ros2` Works in One Terminal but Not Another

Source the environment in every terminal:

```bash
source /opt/ros/humble/setup.bash
source ~/teleop_ws/install/setup.bash
```

## SpaceMouse Topics Are Missing

`teleop.sh` tries to start `spacenavd` automatically; check the daemon if
input is still dead:

```bash
systemctl status spacenavd --no-pager
sudo systemctl restart spacenavd
lsusb | grep -i 3dconnexion
```

Then verify the ROS side:

```bash
scripts/check_spacemouse_topics.sh
# or manually:
ros2 topic echo /spacenav/twist
```

## Servo Does Not Start

If `teleop.sh` times out waiting for `/servo_node/start_servo`, look at
`~/teleop_logs/<timestamp>/stack.log`. A common cause: the Servo config uses
the `grav_tcp` end-effector frame, which only exists in the URDF when the
gripper model is loaded. Start with the gripper model (`load_gripper:=true`,
the default; do not pass `--no-gripper`), or change `ee_frame_name` in
`config/rizon_moveit_servo_config.lab.yaml` and re-run
`scripts/apply_servo_config.sh`.

If the Servo config drifted from the repo-managed version:

```bash
scripts/apply_servo_config.sh --check   # show the diff
scripts/apply_servo_config.sh           # reinstall the repo config
```

## Servo Runs but the Arm Does Not Move

Check that Servo is enabled and commands arrive:

```bash
ros2 node list | grep servo
ros2 service call /servo_node/start_servo std_srvs/srv/Trigger "{}"
ros2 topic echo /servo_node/delta_twist_cmds
```

Remember the deadman: the bridge forwards motion only while SpaceMouse button
`0` is held. If `/servo_node/delta_twist_cmds` shows zeros while you hold the
button and move the puck, check `/spacenav/twist` and `/spacenav/joy`.

## Another Motion Command Is Being Ignored

While the bridge is running with the default `publish_when_idle: true`, it
publishes zero twists at 50 Hz even when idle, so Servo stays active and holds
the arm controller — any parallel trajectory or MoveIt plan is overridden.
Stop Servo first (`scripts/restore_start_state.sh` does this automatically),
or set `publish_when_idle: false` in `config/spacemouse_teleop.yaml`.

## A Stack Is "Already Running"

`teleop.sh` and the run scripts refuse to start on top of an existing
Flexiv/Servo stack. Stop it and retry:

```bash
scripts/stop_ros_stack.sh
```

The stop script escalates INT -> TERM -> KILL and reports any process it could
not stop.

## Gripper Button Does Nothing

Check that the gripper action server exists:

```bash
ros2 action list | grep flexiv_gripper_node
```

The bridge logs a throttled warning when the server is unavailable and logs
rejected goals. If the server exists but goals fail, initialize the GN01 —
required once after every controller power-cycle, and only while the ROS stack
is stopped (the robot accepts a single RDK connection):

```bash
scripts/stop_ros_stack.sh
ROBOT_SN=Rizon4s-062626 python3 scripts/init_gn01_once.py
```

This needs the `flexivrdk==1.7.0` pip package (checked by `doctor.sh`; the
install script installs it). Note the v1.7 gripper server ignores
`max_effort` — gripping force cannot be tuned from this repo.

## Recorded Bag Has Empty Robot-State Topics

Robot topic names are derived from `ROBOT_SN` with hyphens replaced by
underscores (e.g. `/Rizon4s_062626/tcp_pose`). A wrong SN means the recorder
subscribes to topics nobody publishes. `record_demo.sh` now requires an
explicit `ROBOT_SN` and refuses to record unadvertised topics — if it lists
missing topics, fix the SN or start the missing publishers instead of forcing
`ALLOW_MISSING_TOPICS=true`. Compare with:

```bash
ros2 topic list | grep -i rizon
```

## Camera Stream Missing or Wrong Resolution

```bash
scripts/check_camera_topics.sh
v4l2-ctl --list-devices
```

The ZED 2i's UVC output is a 2560x720 side-by-side stereo pair (HD720); it
does not offer plain 640x480. Crop the left half downstream for a single RGB
view.

## Robot Ping Fails

```bash
ip -br addr
ip route get 192.168.100.1
ping 192.168.100.1
```

If the owner machine is directly connected to the Flexiv general port, keep
MTU at 1500 and use automatic IPv4 unless your lab network policy says
otherwise.

## Robot Ignores Commands After a Fault or E-stop

The flexiv_ros2 v1.7 driver silently drops commands after a fault. Release the
E-stop, clear the fault (Flexiv Elements or RDK `ClearFault`), then **restart
the ROS stack** (`Ctrl-C` and re-run `teleop.sh`). See the E-stop section of
[SAFETY.md](SAFETY.md).
