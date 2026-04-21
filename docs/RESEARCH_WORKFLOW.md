# Research Workflow

This stack is designed to get reliable human demonstrations before adding more
camera or policy-learning infrastructure.

## Recommended Bring-up Order

1. Fake hardware teleop.
2. Real robot with no objects.
3. Real robot with simple pick/place props.
4. Add fixed global camera.
5. Add rosbag recorder.
6. Convert bags into policy-learning datasets.

## Suggested Topics for Demonstrations

```text
/spacenav/twist
/spacenav/joy
/joint_states
/${ROBOT_SN}/flexiv_robot_states
/${ROBOT_SN}/tcp_pose
/${ROBOT_SN}/external_wrench_in_tcp
/${ROBOT_SN}/external_wrench_in_world
/servo_node/status
/rizon_arm_controller/joint_trajectory
```

Add camera topics later, for example ZED color images, depth, and camera info.

## Dataset Notes

- Store raw bags unchanged.
- Write converted datasets to a separate directory.
- Keep robot serial, workspace layout, camera pose, and task description in metadata.
- Record failed attempts; they are useful for debugging teleop and reset policy.

