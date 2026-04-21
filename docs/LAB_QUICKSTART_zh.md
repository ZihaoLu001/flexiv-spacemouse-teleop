# 实验室快速手册

这份手册给实验室同学用。默认 owner machine 是连接 Flexiv、SpaceMouse、相机的 Ubuntu 22.04 主机。

## 第一次安装

```bash
mkdir -p ~/teleop_ws/src
cd ~/teleop_ws/src
git clone https://github.com/ZihaoLu001/flexiv-spacemouse-teleop.git
cd flexiv-spacemouse-teleop

scripts/install_owner_machine_ubuntu22_humble.sh
scripts/fetch_flexiv_ros2_humble_v1_7.sh
scripts/build_workspace.sh
```

## 每次使用前检查

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop
export ROBOT_SN=<你的机器人序列号>
export RIZON_TYPE=Rizon4s
scripts/doctor.sh
```

确认：

- `spacenavd` 是 active
- `ping 192.168.100.1` 成功
- `flexiv_spacemouse_teleop` 能被 ROS 找到
- 没有旧的 `servo_node_main` / `move_group` / `ros2_control_node`

## Fake Hardware

终端 1：

```bash
export ROBOT_SN=<你的机器人序列号>
export RIZON_TYPE=Rizon4s
scripts/run_fake_moveit_servo.sh
```

终端 2：

```bash
scripts/start_servo.sh
scripts/run_spacemouse_bridge.sh enable_gripper:=false
```

## 真机

真机前先确认急停、工作空间和 Remote Mode。

终端 1：

```bash
export ROBOT_SN=<你的机器人序列号>
export RIZON_TYPE=Rizon4s
python3 scripts/init_gn01_once.py
scripts/run_real_moveit_servo.sh
```

终端 2：

```bash
scripts/start_servo.sh
scripts/run_spacemouse_bridge.sh
```

## 录 demos

需要图像观测时，先开 ZED 2i RGB：

```bash
scripts/run_zed_rgb_camera.sh
```

检查相机 topic：

```bash
scripts/check_camera_topics.sh
```

终端 3：

```bash
scripts/record_demo.sh
```

默认保存到：

```text
~/teleop_demos/YYYYMMDD_HHMMSS
```
