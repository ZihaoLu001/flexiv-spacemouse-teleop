#!/usr/bin/env python3
"""Map SpaceMouse buttons to Flexiv-GN01 gripper actions."""

from __future__ import annotations

import rclpy
from control_msgs.action import GripperCommand
from rclpy.action import ActionClient
from rclpy.node import Node
from sensor_msgs.msg import Joy


class SpaceMouseGN01(Node):
    def __init__(self) -> None:
        super().__init__("spacemouse_gn01")

        self.declare_parameter("joy_topic", "/spacenav/joy")
        self.declare_parameter("action_name", "/flexiv_gripper_node/gripper_action")
        self.declare_parameter("open_button_idx", -1)
        self.declare_parameter("close_button_idx", -1)
        self.declare_parameter("toggle_button_idx", 1)
        self.declare_parameter("initial_toggle_is_open", False)
        self.declare_parameter("open_width", 0.09)
        self.declare_parameter("close_width", 0.01)
        # NOTE: flexiv_ros2 humble-v1.7's gripper_action server moves the GN01
        # with fixed internal velocity/force constants and ignores max_effort.
        # The value is still sent for forward compatibility with newer servers.
        self.declare_parameter("max_force", 20.0)

        self.joy_topic = self.get_parameter("joy_topic").value
        self.action_name = self.get_parameter("action_name").value
        self.open_button_idx = int(self.get_parameter("open_button_idx").value)
        self.close_button_idx = int(self.get_parameter("close_button_idx").value)
        self.toggle_button_idx = int(self.get_parameter("toggle_button_idx").value)
        self.toggle_is_open = bool(self.get_parameter("initial_toggle_is_open").value)
        self.open_width = float(self.get_parameter("open_width").value)
        self.close_width = float(self.get_parameter("close_width").value)
        self.max_force = float(self.get_parameter("max_force").value)

        self.prev_buttons = []
        self.last_warn_time = None
        self.client = ActionClient(self, GripperCommand, self.action_name)
        self.create_subscription(Joy, self.joy_topic, self.joy_cb, 10)

        self.get_logger().info(f"GN01 button bridge targeting {self.action_name}")

    def _throttled_warn(self, text: str) -> None:
        now = self.get_clock().now()
        if (
            self.last_warn_time is None
            or (now - self.last_warn_time).nanoseconds * 1e-9 > 2.0
        ):
            self.get_logger().warn(text)
            self.last_warn_time = now

    def send_move(self, width: float, toggle_becomes_open: bool | None = None) -> None:
        """Send a gripper goal; advance toggle state only once the goal is accepted."""
        if not self.client.server_is_ready():
            self._throttled_warn("Gripper action server is not available; command dropped.")
            return

        goal = GripperCommand.Goal()
        goal.command.position = width
        goal.command.max_effort = self.max_force

        future = self.client.send_goal_async(goal)

        def _on_goal_response(fut) -> None:
            handle = fut.result()
            if handle is None or not handle.accepted:
                self.get_logger().warn(f"Gripper goal (width={width:.3f}) was rejected.")
                return
            if toggle_becomes_open is not None:
                self.toggle_is_open = toggle_becomes_open
            handle.get_result_async().add_done_callback(_on_result)

        def _on_result(fut) -> None:
            result = fut.result()
            if result is None:
                self.get_logger().warn("Gripper action returned no result.")
                return
            if not result.result.reached_goal and result.result.stalled:
                self.get_logger().info(
                    f"Gripper stalled at {result.result.position:.3f} m (likely grasping)."
                )

        future.add_done_callback(_on_goal_response)

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
            self.send_move(self.open_width, toggle_becomes_open=True)

        if self._rising_edge(buttons, self.close_button_idx):
            self.get_logger().info("GN01 CLOSE")
            self.send_move(self.close_width, toggle_becomes_open=False)

        if self._rising_edge(buttons, self.toggle_button_idx):
            if self.toggle_is_open:
                self.get_logger().info("GN01 TOGGLE -> CLOSE")
                self.send_move(self.close_width, toggle_becomes_open=False)
            else:
                self.get_logger().info("GN01 TOGGLE -> OPEN")
                self.send_move(self.open_width, toggle_becomes_open=True)

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
