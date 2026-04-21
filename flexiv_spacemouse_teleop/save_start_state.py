#!/usr/bin/env python3
import argparse
import json
import math
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import rclpy
from rclpy.node import Node
from sensor_msgs.msg import JointState


class JointStateSaver(Node):
    def __init__(self, topic: str, min_joints: int):
        super().__init__("save_start_state")
        self.min_joints = min_joints
        self.message = None
        self.subscription = self.create_subscription(JointState, topic, self._callback, 10)

    def _callback(self, msg: JointState):
        if len(msg.name) < self.min_joints or len(msg.position) < self.min_joints:
            return

        pairs = []
        for name, position in zip(msg.name, msg.position):
            if name and math.isfinite(position):
                pairs.append((name, float(position)))

        if len(pairs) >= self.min_joints:
            self.message = msg


def _default_output_path() -> Path:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    return Path.home() / "teleop_sessions" / stamp / "start_joint_state.json"


def _parse_args():
    parser = argparse.ArgumentParser(
        description="Save the current /joint_states message as a teleoperation return target."
    )
    parser.add_argument("--topic", default="/joint_states", help="JointState topic to sample.")
    parser.add_argument(
        "--output",
        default=str(_default_output_path()),
        help="Output JSON path. Defaults to ~/teleop_sessions/<timestamp>/start_joint_state.json.",
    )
    parser.add_argument("--timeout", type=float, default=10.0, help="Seconds to wait for a valid sample.")
    parser.add_argument("--min-joints", type=int, default=6, help="Minimum joints required in the sample.")
    return parser.parse_args()


def main():
    args = _parse_args()
    output_path = Path(os.path.expanduser(args.output)).resolve()

    rclpy.init()
    node = JointStateSaver(args.topic, args.min_joints)

    deadline = node.get_clock().now().nanoseconds + int(args.timeout * 1e9)
    try:
        while rclpy.ok() and node.message is None:
            rclpy.spin_once(node, timeout_sec=0.1)
            if node.get_clock().now().nanoseconds > deadline:
                raise TimeoutError(f"No valid JointState received on {args.topic} within {args.timeout:.1f}s")

        msg = node.message
        assert msg is not None
        positions = {
            name: float(position)
            for name, position in zip(msg.name, msg.position)
            if name and math.isfinite(position)
        }

        payload = {
            "schema": "flexiv_spacemouse_teleop.start_joint_state.v1",
            "created_at": datetime.now(timezone.utc).isoformat(),
            "topic": args.topic,
            "joint_names": list(positions.keys()),
            "positions": positions,
            "source_stamp": {
                "sec": int(msg.header.stamp.sec),
                "nanosec": int(msg.header.stamp.nanosec),
            },
        }

        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        print(output_path)
    except Exception as exc:
        node.get_logger().error(str(exc))
        return_code = 1
    else:
        return_code = 0
    finally:
        node.destroy_node()
        rclpy.shutdown()

    sys.exit(return_code)


if __name__ == "__main__":
    main()
