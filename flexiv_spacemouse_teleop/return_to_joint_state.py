#!/usr/bin/env python3
import argparse
import json
import math
import os
import re
import sys
from pathlib import Path

import rclpy
from builtin_interfaces.msg import Duration
from control_msgs.action import FollowJointTrajectory
from rclpy.action import ActionClient
from rclpy.node import Node
from sensor_msgs.msg import JointState
from trajectory_msgs.msg import JointTrajectoryPoint


class JointStateReturner(Node):
    def __init__(self, joint_topic: str, controller_action: str):
        super().__init__("return_to_joint_state")
        self.current = None
        self.update_count = 0
        self.subscription = self.create_subscription(JointState, joint_topic, self._joint_state_cb, 10)
        self.client = ActionClient(self, FollowJointTrajectory, controller_action)

    def _joint_state_cb(self, msg: JointState):
        self.current = {
            name: float(position)
            for name, position in zip(msg.name, msg.position)
            if name and math.isfinite(position)
        }
        self.update_count += 1

    def wait_for_current_state(self, timeout: float, min_update_count=None):
        deadline = self.get_clock().now().nanoseconds + int(timeout * 1e9)
        while rclpy.ok() and (
            self.current is None or (min_update_count is not None and self.update_count <= min_update_count)
        ):
            rclpy.spin_once(self, timeout_sec=0.1)
            if self.get_clock().now().nanoseconds > deadline:
                raise TimeoutError("Timed out waiting for current /joint_states")

    def send_goal(self, joint_names, positions, duration_sec: float, wait_timeout: float, goal_tolerance: float):
        if not self.client.wait_for_server(timeout_sec=wait_timeout):
            raise TimeoutError("FollowJointTrajectory action server is not available")

        goal = FollowJointTrajectory.Goal()
        goal.trajectory.joint_names = joint_names

        point = JointTrajectoryPoint()
        point.positions = [positions[name] for name in joint_names]
        point.velocities = [0.0 for _ in joint_names]
        point.time_from_start = Duration(sec=int(duration_sec), nanosec=int((duration_sec % 1.0) * 1e9))
        goal.trajectory.points = [point]

        future = self.client.send_goal_async(goal)
        rclpy.spin_until_future_complete(self, future)
        goal_handle = future.result()
        if goal_handle is None or not goal_handle.accepted:
            raise RuntimeError("Return trajectory goal was rejected")

        result_future = goal_handle.get_result_async()
        rclpy.spin_until_future_complete(self, result_future)
        result = result_future.result()
        if result is None:
            raise RuntimeError("Return trajectory did not return a result")
        if result.result.error_code != FollowJointTrajectory.Result.SUCCESSFUL:
            raise RuntimeError(
                f"Return trajectory failed with error_code={result.result.error_code}: "
                f"{result.result.error_string}"
            )

        previous_update_count = self.update_count
        self.wait_for_current_state(wait_timeout, min_update_count=previous_update_count)
        assert self.current is not None
        final_errors = {name: abs(positions[name] - self.current[name]) for name in joint_names}
        max_error = max(final_errors.values()) if final_errors else 0.0
        print(f"Final max joint error: {max_error:.4f} rad")
        if max_error > goal_tolerance:
            raise RuntimeError(
                f"Return trajectory action reported success, but final joint error {max_error:.4f} rad "
                f"exceeds --goal-tolerance {goal_tolerance:.4f}. Stop Servo/teleop publishers and retry."
            )


def _load_state(path: Path):
    payload = json.loads(path.read_text(encoding="utf-8"))
    positions = payload.get("positions")
    if not isinstance(positions, dict) or not positions:
        raise ValueError(f"No positions found in {path}")
    joint_names = payload.get("joint_names")
    if not isinstance(joint_names, list) or not joint_names:
        joint_names = list(positions.keys())
    return {name: float(value) for name, value in positions.items()}, [str(name) for name in joint_names]


def _parse_joint_filter(value: str):
    if not value:
        return None
    return [part.strip() for part in value.split(",") if part.strip()]


def _parse_args():
    parser = argparse.ArgumentParser(
        description="Return the arm to a saved teleoperation start joint state."
    )
    parser.add_argument("state_file", help="JSON state file created by save_start_state.")
    parser.add_argument("--joint-topic", default="/joint_states", help="Current JointState topic.")
    parser.add_argument(
        "--controller-action",
        default="/rizon_arm_controller/follow_joint_trajectory",
        help="FollowJointTrajectory action server.",
    )
    parser.add_argument("--duration", type=float, default=8.0, help="Trajectory duration in seconds.")
    parser.add_argument(
        "--max-delta",
        type=float,
        default=0.7,
        help="Maximum allowed per-joint return distance in radians unless --force is passed.",
    )
    parser.add_argument(
        "--max-speed",
        type=float,
        default=0.25,
        help="Maximum implied per-joint return speed in rad/s unless --force is passed.",
    )
    parser.add_argument("--wait-timeout", type=float, default=10.0, help="Seconds to wait for ROS interfaces.")
    parser.add_argument(
        "--joints",
        default="",
        help="Comma-separated joint names to command. Defaults to intersection of saved and current joints.",
    )
    parser.add_argument(
        "--include-regex",
        default=r"(^|_)joint[0-9]+$",
        help="Regex used to select arm joints when --joints is not provided.",
    )
    parser.add_argument("--execute", action="store_true", help="Actually send the return trajectory.")
    parser.add_argument("--force", action="store_true", help="Allow joint deltas larger than --max-delta.")
    parser.add_argument(
        "--goal-tolerance",
        type=float,
        default=0.04,
        help="Maximum allowed final per-joint error in radians after an executed return trajectory.",
    )
    return parser.parse_args()


def main():
    args = _parse_args()
    state_path = Path(os.path.expanduser(args.state_file)).resolve()

    rclpy.init()
    node = JointStateReturner(args.joint_topic, args.controller_action)

    try:
        target_positions, saved_joint_names = _load_state(state_path)
        if args.duration <= 0.0:
            raise ValueError("--duration must be positive")

        node.wait_for_current_state(args.wait_timeout)
        assert node.current is not None

        requested_joints = _parse_joint_filter(args.joints)
        if requested_joints is None:
            include_re = re.compile(args.include_regex)
            joint_names = [
                name
                for name in saved_joint_names
                if name in target_positions and name in node.current and include_re.search(name)
            ]
        else:
            joint_names = requested_joints

        missing = [name for name in joint_names if name not in target_positions or name not in node.current]
        if missing:
            raise ValueError(f"Requested joints are missing from saved or current state: {', '.join(missing)}")
        if len(joint_names) < 6:
            raise ValueError(f"Only {len(joint_names)} joints selected; refusing to command return trajectory")

        deltas = {name: abs(target_positions[name] - node.current[name]) for name in joint_names}
        max_delta = max(deltas.values()) if deltas else 0.0
        max_speed = max_delta / args.duration

        print(f"State file: {state_path}")
        print(f"Controller: {args.controller_action}")
        print(f"Joints: {', '.join(joint_names)}")
        print(f"Max return delta: {max_delta:.4f} rad")
        print(f"Max implied speed: {max_speed:.4f} rad/s over {args.duration:.1f}s")

        if max_delta > args.max_delta and not args.force:
            raise RuntimeError(
                f"Max joint delta {max_delta:.4f} rad exceeds --max-delta {args.max_delta:.4f}. "
                "Inspect the robot and rerun with --force only if this is intentional."
            )
        if max_speed > args.max_speed and not args.force:
            raise RuntimeError(
                f"Max implied joint speed {max_speed:.4f} rad/s exceeds --max-speed {args.max_speed:.4f}. "
                "Increase --duration, inspect the robot, or rerun with --force only if this is intentional."
            )

        if not args.execute:
            print("Dry run only. Rerun with --execute to move the robot.")
            return_code = 0
        else:
            node.send_goal(joint_names, target_positions, args.duration, args.wait_timeout, args.goal_tolerance)
            print("Return trajectory completed.")
            return_code = 0
    except Exception as exc:
        node.get_logger().error(str(exc))
        return_code = 1
    finally:
        node.destroy_node()
        rclpy.shutdown()

    sys.exit(return_code)


if __name__ == "__main__":
    main()
