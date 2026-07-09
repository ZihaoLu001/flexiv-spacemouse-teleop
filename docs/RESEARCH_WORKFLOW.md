# Research Workflow

This stack is designed to get reliable human demonstrations before adding more
camera or policy-learning infrastructure.

## Recommended Bring-up Order

1. Fake hardware teleop (`scripts/teleop.sh`).
2. Real robot with no objects (`ROBOT_SN=... scripts/teleop.sh --real`).
3. Real robot with simple pick/place props.
4. Add the fixed global camera (`--camera`).
5. Record demonstrations (`--record`).
6. Convert bags into policy-learning datasets.

## Recording

The recommended path is the one-command flow:

```bash
ROBOT_SN=Rizon4s-062626 scripts/teleop.sh --real --camera --record
```

This uses `scripts/record_demo.sh` underneath, which requires an explicit
`ROBOT_SN` and refuses to record topics that are not advertised (a wrong SN
would otherwise produce silently empty robot-state tracks).

## Recorded Topics

Robot-specific topic names are derived from the serial number with hyphens
replaced by underscores (`${ROBOT_SN//-/_}` in `record_demo.sh`), because
ROS 2 topic names cannot contain `-`. For `ROBOT_SN=Rizon4s-062626`:

```text
/spacenav/twist
/spacenav/joy
/joint_states
/flexiv_arm/joint_states
/flexiv_gripper_node/gripper_joint_states
/Rizon4s_062626/flexiv_robot_states
/Rizon4s_062626/tcp_pose
/Rizon4s_062626/external_wrench_in_tcp
/Rizon4s_062626/external_wrench_in_world
/Rizon4s_062626/ft_sensor_wrench
/servo_node/status
/servo_node/delta_twist_cmds
/rizon_arm_controller/joint_trajectory
/rizon_arm_controller/state
```

Camera topics are added according to `CAMERA_MODE` (default `compressed`:
`/zed2i/image_raw/compressed` + `/zed2i/camera_info`; `raw` records the full
2560x720 side-by-side stream and produces much larger bags; `none` records
proprioception only).

## On-Disk Layout

Each recording lands in a timestamped directory:

```text
~/teleop_demos/<YYYYMMDD_HHMMSS>/
  rosbag/       the ros2 bag
  README.txt    robot_sn, topic namespace, camera mode, start time, topic list
```

## Dataset Notes

- Store raw bags unchanged.
- Write converted datasets to a separate directory.
- Keep robot serial, workspace layout, camera pose, and task description in
  metadata (`README.txt` records the machine-derived part automatically).
- Record failed attempts; they are useful for debugging teleop and reset
  policy.
