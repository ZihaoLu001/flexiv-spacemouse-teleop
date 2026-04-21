# Installation Guide

This guide assumes the owner machine is the Ubuntu PC physically connected to
the Flexiv control box, SpaceMouse, and optional camera.

## 1. Install Owner Machine Dependencies

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
scripts/install_owner_machine_ubuntu22_humble.sh
```

The script installs ROS 2 Humble, MoveIt, MoveIt Servo, ros2_control,
`spacenavd`, and the ROS `spacenav` package.

## 2. Fetch Flexiv ROS 2

```bash
mkdir -p ~/teleop_ws/src
cd ~/teleop_ws/src
git clone https://github.com/ZihaoLu001/flexiv-spacemouse-teleop.git
cd flexiv-spacemouse-teleop
scripts/fetch_flexiv_ros2_humble_v1_7.sh
```

Use `humble-v1.7` for Flexiv software package v3.9 / RDK v1.7 compatibility.

## 3. Build

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
scripts/build_workspace.sh
```

This builds Flexiv RDK dependencies into `~/rdk_install`, then builds the ROS 2
workspace.

## 4. Source the Workspace

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

