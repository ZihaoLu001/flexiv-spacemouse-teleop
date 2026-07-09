# Installation Guide

This guide assumes the owner machine is the Ubuntu 22.04 PC physically
connected to the Flexiv control box, SpaceMouse, and optional camera.

## 1. Create the Workspace and Clone the Sources

```bash
mkdir -p ~/teleop_ws/src
cd ~/teleop_ws/src
git clone https://github.com/ZihaoLu001/flexiv-spacemouse-teleop.git
cd flexiv-spacemouse-teleop
scripts/fetch_flexiv_ros2_humble_v1_7.sh
```

`fetch_flexiv_ros2_humble_v1_7.sh` clones `flexiv_ros2` at `humble-v1.7`
(with submodules) into `~/teleop_ws/src/flexiv_ros2`. Use `humble-v1.7` to
match robot software v1.7; on re-runs it refuses to clobber unexpected local
modifications (the only sanctioned local change is the Servo config installed
in step 4).

## 2. Install Owner Machine Dependencies

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
scripts/install_owner_machine_ubuntu22_humble.sh
```

The script enables the `universe` repository, installs ROS 2 Humble, MoveIt,
MoveIt Servo, ros2_control, `spacenavd`, the ROS `spacenav` package, the V4L2
camera tools used for the ZED 2i RGB stream, and the `flexivrdk==1.7.0` Python
package. `flexivrdk` is required by `scripts/init_gn01_once.py` (one-time
gripper initialization) and its version must pair exactly with the robot
software (v1.7). It also enables the `spacenavd` service.

## 3. Build

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
scripts/build_workspace.sh
```

This builds the Flexiv RDK C++ dependencies into `~/rdk_install`, then builds
the ROS 2 workspace with `colcon build --symlink-install`.

## 4. Install the Repo-Managed Servo Config

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
scripts/apply_servo_config.sh
```

This installs `config/rizon_moveit_servo_config.lab.yaml` into the
`flexiv_ros2` checkout (backing up the upstream file). See the "Servo Config
Management" section of the [README](../README.md) — never hand-edit the copy
inside `flexiv_ros2`.

## 5. Source the Workspace

Add this to `~/.bashrc` on the owner machine:

```bash
source /opt/ros/humble/setup.bash
source ~/teleop_ws/install/setup.bash
```

Open a new terminal and verify:

```bash
ros2 pkg list | grep flexiv_spacemouse_teleop
ros2 pkg executables flexiv_spacemouse_teleop
```

## 6. Verify with doctor.sh

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
scripts/doctor.sh
```

`doctor.sh` exits non-zero and prints `PROBLEM:` lines if anything is missing
or misconfigured (ROS packages, `flexivrdk` version pairing, Servo config
safety keys, `spacenavd`, robot network, ...).

## 7. Run It

```bash
# Fake hardware, no robot needed:
scripts/teleop.sh

# Real robot:
ROBOT_SN=Rizon4s-062626 scripts/teleop.sh --real
```

See the [operator manual](OPERATOR_MANUAL.md) and the
[safety checklist](SAFETY.md) before the first real-robot run.
