#!/usr/bin/env python3
"""Initialize the Flexiv-GN01 gripper once after controller power-cycle."""

import os
import time

import flexivrdk


ROBOT_SN = os.environ.get("ROBOT_SN", "Rizon4s-123456")
GRIPPER_NAME = os.environ.get("GRIPPER_NAME", "Flexiv-GN01")


def main() -> None:
    robot = flexivrdk.Robot(ROBOT_SN)
    robot.Enable()
    while not robot.operational():
        time.sleep(0.1)

    gripper = flexivrdk.Gripper(robot)
    gripper.Enable(GRIPPER_NAME)
    gripper.Init()
    time.sleep(5.0)

    print(f"{GRIPPER_NAME} initialized for {ROBOT_SN}.")


if __name__ == "__main__":
    main()
