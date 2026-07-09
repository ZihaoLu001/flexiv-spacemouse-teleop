#!/usr/bin/env python3
"""Initialize the Flexiv-GN01 gripper once after controller power-cycle.

Follows the official RDK sequence (flexiv_rdk example_py/basics6_gripper_control.py):
clear fault -> Enable -> Gripper.Enable -> Tool.Switch -> Gripper.Init -> wait.

Requires the `flexivrdk` pip package matching the robot software (v1.7 here).
Run this ONLY while the ROS 2 stack is stopped: the robot accepts a single RDK
connection, and flexiv_ros2's hardware interface already holds it when running.
"""

import os
import subprocess
import sys
import time

import flexivrdk

ROBOT_SN = os.environ.get("ROBOT_SN", "")
GRIPPER_NAME = os.environ.get("GRIPPER_NAME", "Flexiv-GN01")
OPERATIONAL_TIMEOUT_S = float(os.environ.get("OPERATIONAL_TIMEOUT_S", "30"))
# The official gripper action server waits 10 s after Init() before reporting
# success; Init() itself is non-blocking.
INIT_WAIT_S = float(os.environ.get("INIT_WAIT_S", "10"))


def main() -> int:
    if not ROBOT_SN or ROBOT_SN == "Rizon4s-123456":
        print("Refusing to run without an explicit ROBOT_SN.", file=sys.stderr)
        print(f"Example: ROBOT_SN=Rizon4s-062626 {sys.argv[0]}", file=sys.stderr)
        return 2

    ros_stack = subprocess.run(
        ["pgrep", "-af", "ros2_control_node|servo_node_main|ros2 launch flexiv"],
        capture_output=True,
        text=True,
    ).stdout.strip()
    if ros_stack:
        print(
            "Refusing to run: the ROS 2 stack holds the robot's single RDK "
            "connection. Run scripts/stop_ros_stack.sh first.",
            file=sys.stderr,
        )
        print(ros_stack, file=sys.stderr)
        return 2

    robot = flexivrdk.Robot(ROBOT_SN)

    if robot.fault():
        print("Robot fault detected, attempting to clear ...")
        if not robot.ClearFault():
            print("Fault could not be cleared; resolve it in Flexiv Elements first.", file=sys.stderr)
            return 1
        print("Fault cleared.")

    print("Enabling robot (make sure the E-stop is released) ...")
    robot.Enable()
    deadline = time.monotonic() + OPERATIONAL_TIMEOUT_S
    while not robot.operational():
        if time.monotonic() > deadline:
            print(
                f"Robot did not become operational within {OPERATIONAL_TIMEOUT_S:.0f}s. "
                "Check the E-stop and Flexiv Elements.",
                file=sys.stderr,
            )
            return 1
        time.sleep(0.1)

    gripper = flexivrdk.Gripper(robot)
    tool = flexivrdk.Tool(robot)

    print(f"Enabling gripper [{GRIPPER_NAME}] ...")
    gripper.Enable(GRIPPER_NAME)

    print(f"Switching robot tool to [{GRIPPER_NAME}] (updates gravity compensation and TCP) ...")
    tool.Switch(GRIPPER_NAME)

    print("Triggering gripper initialization ...")
    gripper.Init()
    print(f"Waiting {INIT_WAIT_S:.0f}s for the initialization sequence to finish ...")
    time.sleep(INIT_WAIT_S)

    states = gripper.states()
    print(f"{GRIPPER_NAME} initialized for {ROBOT_SN}. width={states.width:.3f} m")
    return 0


if __name__ == "__main__":
    sys.exit(main())
