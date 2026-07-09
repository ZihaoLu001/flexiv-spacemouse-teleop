# Changelog

## 0.2.0 (2026-07-09)

Audit-driven release: every confirmed finding from the July 2026 conformance
audit is addressed, and teleoperation now starts with a single command.

### Added
- `scripts/teleop.sh`: one-command teleoperation (preflight, robot stack,
  Servo enable, bridges, clean shutdown on Ctrl-C). Fake hardware by default,
  `--real` for the robot, plus `--camera`, `--record`, `--no-gripper`,
  `--keep-stack`.
- `config/rizon_moveit_servo_config.lab.yaml`: the MoveIt Servo configuration
  this repo depends on is now version-controlled here (frames, timing,
  `check_collisions: true`), installed by `scripts/apply_servo_config.sh`
  (with `--check` and `--restore`). Replaces hand-edits / `sed` of the
  vendored flexiv_ros2 tree.
- CI now builds the package and runs unit tests on ROS 2 Humble
  (`.github/workflows/ci.yml`), plus shell syntax checks.
- Unit tests for deadband/clamp/slew and button edge detection.

### Changed
- **Breaking:** `launch/spacemouse_teleop.launch.py` no longer overrides YAML
  parameters with launch-argument defaults; `config/spacemouse_teleop.yaml` is
  the single source of truth (previously `require_enable_button`,
  `enable_button_idx`, `output_topic` and `frame_id` in the YAML were silently
  ignored).
- `scripts/run_real_moveit_servo.sh` defaults to `LOAD_GRIPPER=true` (matching
  the lab deployment) and refuses to start when the Servo config uses the
  `grav_tcp` frame without the gripper model loaded.
- `scripts/stop_ros_stack.sh` verifies processes actually exit, escalates
  INT -> TERM -> KILL, includes `flexiv_gripper_node`, and reports failures.
- `scripts/record_demo.sh` requires an explicit `ROBOT_SN` and refuses to
  record topics that are not advertised (previously wrong SNs silently
  produced empty robot-state tracks).
- `scripts/init_gn01_once.py` follows the official RDK sequence (fault check,
  operational timeout, `Tool.Switch`, 10 s init wait), refuses placeholder
  serial numbers, and refuses to run while the ROS stack holds the RDK
  connection.
- `scripts/doctor.sh` now fails loudly, and additionally checks `spacenav` /
  `moveit_servo` / `v4l2_camera` packages, the `flexivrdk` Python package and
  version pairing, and Servo config safety keys.
- `scripts/install_owner_machine_ubuntu22_humble.sh` enables `universe` before
  installing (spacenavd lives there) and installs `flexivrdk==1.7.0`.
- `return_to_joint_state` gates on estimated peak joint speed (~1.5x average)
  instead of average speed, cancels the trajectory goal on Ctrl-C, and
  requires 7 joints (Rizon arms are 7-DOF); `save_start_state` likewise
  defaults to 7 minimum joints.
- `spacemouse_gn01` advances the toggle state only after the gripper goal is
  accepted, logs rejected/failed goals, and no longer blocks in the joy
  callback; the never-used `velocity` parameter was removed (and note that the
  v1.7 gripper server ignores `max_effort`).
- `spacemouse_to_servo` validates `publish_hz`/`input_timeout`, evaluates the
  stale-input decision once per tick (removing a one-tick unfiltered step at
  the timeout boundary), and gains `publish_when_idle` (default true) to
  optionally release the controller when no motion is commanded.
- `config/zed2i_v4l2.yaml` uses the ZED 2i's actual UVC side-by-side mode
  (2560x720) instead of 640x480, which the camera does not support.
- Docs rewritten around the one-command flow; the GitHub Pages site no longer
  duplicates the Markdown docs (drift-prone); safety docs now document E-stop
  recovery and the return-to-start path assumptions.

### Removed
- `scripts/tune_flexiv_servo_smooth.sh` (replaced by
  `scripts/apply_servo_config.sh` + the version-controlled Servo config).

## 0.1.0 (2026-04-21)

- Initial public release.
- SpaceMouse to MoveIt Servo bridge.
- GN01 gripper button bridge.
- Operator scripts, safety notes, troubleshooting docs, and project website.
