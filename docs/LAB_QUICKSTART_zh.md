# 实验室快速手册

这份手册给实验室同学用。默认 owner machine 是连接 Flexiv、SpaceMouse、相机的
Ubuntu 22.04 主机。日常使用只需要一条命令；分步（多终端）流程见
[OPERATOR_MANUAL.md](OPERATOR_MANUAL.md) 附录。

## 第一次安装

```bash
mkdir -p ~/teleop_ws/src
cd ~/teleop_ws/src
git clone https://github.com/ZihaoLu001/flexiv-spacemouse-teleop.git
cd flexiv-spacemouse-teleop

scripts/fetch_flexiv_ros2_humble_v1_7.sh
scripts/install_owner_machine_ubuntu22_humble.sh
scripts/build_workspace.sh
scripts/apply_servo_config.sh
scripts/doctor.sh
```

安装脚本会装 `flexivrdk==1.7.0`（真机夹爪初始化必需，版本必须和机器人软件
v1.7 严格配对）。`doctor.sh` 有问题会以非零退出并打印 `PROBLEM:` 行，全绿再继续。

## 一键启动

```bash
cd ~/teleop_ws/src/flexiv-spacemouse-teleop

# 无硬件（假硬件模式，随便试）：
scripts/teleop.sh

# 真机（必须显式给序列号）：
ROBOT_SN=Rizon4s-062626 scripts/teleop.sh --real
```

- 按住 SpaceMouse **0 号按钮**（左键）是 deadman，按住才动，松手立即停。
- 按一下 **1 号按钮**（右键）在夹爪开/合之间切换（0.09 m / 0.01 m）。
- **Ctrl-C 会停掉整个 ROS stack**，不需要手动挨个关终端。
- 日志在 `~/teleop_logs/<时间戳>/`（`stack.log`、`bridge.log`）。

常用变体：

```bash
ROBOT_SN=Rizon4s-062626 scripts/teleop.sh --real --record    # 同时录 demo rosbag
ROBOT_SN=Rizon4s-062626 scripts/teleop.sh --real --camera    # 同时开 ZED 2i RGB
scripts/teleop.sh --no-gripper                               # 不加载夹爪
```

`--record` 会把数据存到 `~/teleop_demos/<时间戳>/rosbag`，同目录有一份
`README.txt` 记录序列号和话题清单。

## 真机注意事项

- 真机前确认急停可及、工作空间清空、机器人在 Remote Mode，
  `ping 192.168.100.1` 通。
- 控制柜重新上电后，夹爪要初始化一次，而且必须在 ROS stack **停止时**做
  （机器人只接受一个 RDK 连接）：

```bash
scripts/stop_ros_stack.sh
ROBOT_SN=Rizon4s-062626 python3 scripts/init_gn01_once.py
```

- 第一次真机建议 `--no-gripper` 只测机械臂，方向确认没问题再开夹爪。

## 恢复到起始姿态

开始动机械臂之前，先保存起始关节状态：

```bash
STATE_FILE=$(scripts/save_start_state.sh)
echo "$STATE_FILE"
```

结束时先回起始姿态，再停 stack：

```bash
scripts/restore_start_state.sh "$STATE_FILE"            # 先 dry run 看一眼
scripts/restore_start_state.sh "$STATE_FILE" --execute  # 确认后才真的动
scripts/stop_ros_stack.sh
```

实验室有固定 home 姿态的话，把保存的 state 文件路径写进
`~/teleop_sessions/fixed_home_state.txt`，之后可以省略参数直接
`scripts/restore_start_state.sh --execute`。

注意：

- 不加 `--execute` 只打印 dry run，绝不动机器人。
- restore 脚本会先自动停掉 Servo（否则 teleop 的零速命令会覆盖回程轨迹）。
- 回程是**无碰撞检查**的关节直线插值：执行前必须目视确认路径无障碍。
- 回程距离过大或估算峰值速度过快会被拒绝；检查过现场才可以加 `--force`。

## 急停之后怎么办

松开急停 → 清故障（Flexiv Elements 或 RDK ClearFault）→ **重启整个 ROS
stack**（重新跑一遍 `teleop.sh`；v1.7 驱动在故障后会静默丢弃命令）。
禁止未检查现场就 `restore_start_state.sh --execute`。
完整流程见 [SAFETY.md](SAFETY.md) 的 E-stop 章节。

## 出问题了

先跑 `scripts/doctor.sh`，再看 `~/teleop_logs/<时间戳>/stack.log`，
然后查 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)。
