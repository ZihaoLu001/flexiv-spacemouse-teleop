# Troubleshooting

## `codex` or `ros2` Works in One Terminal but Not Another

Source the environment:

```bash
source /opt/ros/humble/setup.bash
source ~/teleop_ws/install/setup.bash
```

## SpaceMouse Topics Are Missing

Check the daemon:

```bash
systemctl status spacenavd --no-pager
sudo systemctl restart spacenavd
```

Start the node:

```bash
ros2 run spacenav spacenav_node
ros2 topic echo /spacenav/twist
```

## Servo Does Not Move

Check that `/servo_node` exists:

```bash
ros2 node list | grep servo
ros2 node info /servo_node
```

Start Servo:

```bash
ros2 service call /servo_node/start_servo std_srvs/srv/Trigger "{}"
```

Check command topic:

```bash
ros2 topic echo /servo_node/delta_twist_cmds
```

## Gripper Button Does Nothing

Check that the gripper action exists:

```bash
ros2 action list | grep flexiv_gripper_node
```

Initialize GN01 once after controller power-cycle:

```bash
python3 ~/teleop_ws/src/flexiv-spacemouse-teleop/scripts/init_gn01_once.py
```

## Robot Ping Fails

Check routes and interface:

```bash
ip -br addr
ip route get 192.168.100.1
ping 192.168.100.1
```

If the owner machine is directly connected to the Flexiv general port, keep MTU
at 1500 and use automatic IPv4 unless your lab network policy says otherwise.

