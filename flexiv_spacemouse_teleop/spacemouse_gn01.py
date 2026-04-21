#!/usr/bin/env python3
"""Map SpaceMouse buttons to Flexiv-GN01 gripper actions."""

from __future__ import annotations

import rclpy
from flexiv_msgs.action import Move
from rclpy.action import ActionClient
from rclpy.node import Node
from sensor_msgs.msg import Joy


class SpaceMouseGN01(Node):
    def __init__(self) -> None:
        super().__init__("spacemouse_gn01")

        self.declare_parameter("joy_topic", "/spacenav/joy")
        self.declare_parameter("action_name", "/flexiv_gripper_node/move")
        self.declare_parameter("open_button_idx", 0)
        self.declare_parameter("close_button_idx", 1)
        self.declare_parameter("open_width", 0.09)
        self.declare_parameter("close_width", 0.01)
        self.declare_parameter("velocity", 0.10)
        self.declare_parameter("max_force", 20.0)
        self.declare_parameter("server_wait_timeout", 0.5)

        self.joy_topic = self.get_parameter("joy_topic").value
        self.action_name = self.get_parameter("action_name").value
        self.open_button_idx = int(self.get_parameter("open_button_idx").value)
        self.close_button_idx = int(self.get_parameter("close_button_idx").value)
        self.open_width = float(self.get_parameter("open_width").value)
        self.close_width = float(self.get_parameter("close_width").value)
        self.velocity = float(self.get_parameter("velocity").value)
        self.max_force = float(self.get_parameter("max_force").value)
        self.server_wait_timeout = float(self.get_parameter("server_wait_timeout").value)

        self.prev_buttons = []
        self.last_warn_time = None
        self.client = ActionClient(self, Move, self.action_name)
        self.create_subscription(Joy, self.joy_topic, self.joy_cb, 10)

        self.get_logger().info(f"GN01 button bridge targeting {self.action_name}")

    def _warn_server_missing(self) -> None:
        now = self.get_clock().now()
        if self.last_warn_time is None:
            should_warn = True
        else:
            should_warn = (now - self.last_warn_time).nanoseconds * 1e-9 > 2.0
        if should_warn:
            self.get_logger().warn("Gripper action server is not available yet.")
            self.last_warn_time = now

    def send_move(self, width: float) -> None:
        if not self.client.wait_for_server(timeout_sec=self.server_wait_timeout):
            self._warn_server_missing()
            return

        goal = Move.Goal()
        goal.width = width
        goal.velocity = self.velocity
        goal.max_force = self.max_force
        self.client.send_goal_async(goal)

    def _rising_edge(self, buttons: list[int], idx: int) -> bool:
        if idx < 0 or idx >= len(buttons) or idx >= len(self.prev_buttons):
            return False
        return buttons[idx] == 1 and self.prev_buttons[idx] == 0

    def joy_cb(self, msg: Joy) -> None:
        buttons = list(msg.buttons)
        if len(buttons) != len(self.prev_buttons):
            self.prev_buttons = buttons
            return

        if self._rising_edge(buttons, self.open_button_idx):
            self.get_logger().info("GN01 OPEN")
            self.send_move(self.open_width)

        if self._rising_edge(buttons, self.close_button_idx):
            self.get_logger().info("GN01 CLOSE")
            self.send_move(self.close_width)

        self.prev_buttons = buttons


def main() -> None:
    rclpy.init()
    node = SpaceMouseGN01()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    node.destroy_node()
    rclpy.shutdown()


if __name__ == "__main__":
    main()

