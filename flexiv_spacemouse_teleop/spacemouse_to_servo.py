#!/usr/bin/env python3
"""Bridge SpaceMouse twist input to MoveIt Servo TwistStamped commands."""

from __future__ import annotations

import rclpy
from geometry_msgs.msg import Twist, TwistStamped
from rclpy.node import Node
from sensor_msgs.msg import Joy


class SpaceMouseToServo(Node):
    def __init__(self) -> None:
        super().__init__("spacemouse_to_servo")

        self.declare_parameter("input_topic", "/spacenav/twist")
        self.declare_parameter("output_topic", "/servo_node/delta_twist_cmds")
        self.declare_parameter("publish_hz", 50.0)
        self.declare_parameter("frame_id", "")
        self.declare_parameter("input_timeout", 0.25)
        self.declare_parameter("enable_topic", "/spacenav/joy")
        self.declare_parameter("require_enable_button", True)
        self.declare_parameter("enable_button_idx", 0)

        # MoveIt Servo config in flexiv_ros2 humble-v1.7 uses unitless commands.
        self.declare_parameter("linear_scale", 0.20)
        self.declare_parameter("angular_scale", 0.40)
        self.declare_parameter("deadband", 0.02)
        self.declare_parameter("clamp_abs", 1.0)
        self.declare_parameter("smoothing_alpha", 0.25)
        self.declare_parameter("max_linear_step", 0.006)
        self.declare_parameter("max_angular_step", 0.010)

        self.declare_parameter("sign_lx", 1.0)
        self.declare_parameter("sign_ly", -1.0)
        self.declare_parameter("sign_lz", 1.0)
        self.declare_parameter("sign_ax", 1.0)
        self.declare_parameter("sign_ay", -1.0)
        self.declare_parameter("sign_az", 1.0)

        self.input_topic = self.get_parameter("input_topic").value
        self.output_topic = self.get_parameter("output_topic").value
        self.publish_hz = float(self.get_parameter("publish_hz").value)
        self.frame_id = self.get_parameter("frame_id").value
        self.input_timeout = float(self.get_parameter("input_timeout").value)
        self.enable_topic = self.get_parameter("enable_topic").value
        self.require_enable_button = bool(self.get_parameter("require_enable_button").value)
        self.enable_button_idx = int(self.get_parameter("enable_button_idx").value)
        self.linear_scale = float(self.get_parameter("linear_scale").value)
        self.angular_scale = float(self.get_parameter("angular_scale").value)
        self.deadband = float(self.get_parameter("deadband").value)
        self.clamp_abs = abs(float(self.get_parameter("clamp_abs").value))
        self.smoothing_alpha = max(0.0, min(1.0, float(self.get_parameter("smoothing_alpha").value)))
        self.max_linear_step = abs(float(self.get_parameter("max_linear_step").value))
        self.max_angular_step = abs(float(self.get_parameter("max_angular_step").value))

        self.sign_lx = float(self.get_parameter("sign_lx").value)
        self.sign_ly = float(self.get_parameter("sign_ly").value)
        self.sign_lz = float(self.get_parameter("sign_lz").value)
        self.sign_ax = float(self.get_parameter("sign_ax").value)
        self.sign_ay = float(self.get_parameter("sign_ay").value)
        self.sign_az = float(self.get_parameter("sign_az").value)

        self.latest = Twist()
        self.filtered = Twist()
        self.last_input_time = None
        self.enable_button_pressed = not self.require_enable_button

        self.create_subscription(Twist, self.input_topic, self.twist_cb, 10)
        if self.require_enable_button:
            self.create_subscription(Joy, self.enable_topic, self.joy_cb, 10)
        self.pub = self.create_publisher(TwistStamped, self.output_topic, 10)
        self.create_timer(1.0 / self.publish_hz, self.timer_cb)

        self.get_logger().info(
            f"Publishing SpaceMouse twist to {self.output_topic} at {self.publish_hz:.1f} Hz"
        )
        if self.require_enable_button:
            self.get_logger().info(
                f"Deadman enabled: hold button {self.enable_button_idx} on {self.enable_topic} to command motion"
            )

    def _apply(self, value: float, scale: float, sign: float) -> float:
        if abs(value) < self.deadband:
            return 0.0
        scaled = sign * scale * value
        return max(-self.clamp_abs, min(self.clamp_abs, scaled))

    def twist_cb(self, msg: Twist) -> None:
        self.latest = msg
        self.last_input_time = self.get_clock().now()

    def joy_cb(self, msg: Joy) -> None:
        if self.enable_button_idx < 0 or self.enable_button_idx >= len(msg.buttons):
            self.enable_button_pressed = False
            return
        self.enable_button_pressed = msg.buttons[self.enable_button_idx] == 1

    def _input_is_stale(self) -> bool:
        if self.last_input_time is None:
            return True
        age = (self.get_clock().now() - self.last_input_time).nanoseconds * 1e-9
        return age > self.input_timeout

    def _slew(self, current: float, target: float, max_step: float) -> float:
        delta = target - current
        if abs(delta) <= max_step:
            return target
        return current + max_step * (1.0 if delta > 0.0 else -1.0)

    def timer_cb(self) -> None:
        msg = Twist() if self._input_is_stale() or not self.enable_button_pressed else self.latest

        target = Twist()
        target.linear.x = self._apply(msg.linear.x, self.linear_scale, self.sign_lx)
        target.linear.y = self._apply(msg.linear.y, self.linear_scale, self.sign_ly)
        target.linear.z = self._apply(msg.linear.z, self.linear_scale, self.sign_lz)
        target.angular.x = self._apply(msg.angular.x, self.angular_scale, self.sign_ax)
        target.angular.y = self._apply(msg.angular.y, self.angular_scale, self.sign_ay)
        target.angular.z = self._apply(msg.angular.z, self.angular_scale, self.sign_az)

        if self._input_is_stale() or not self.enable_button_pressed:
            self.filtered = target
        else:
            alpha = self.smoothing_alpha
            next_linear_x = self.filtered.linear.x + alpha * (target.linear.x - self.filtered.linear.x)
            next_linear_y = self.filtered.linear.y + alpha * (target.linear.y - self.filtered.linear.y)
            next_linear_z = self.filtered.linear.z + alpha * (target.linear.z - self.filtered.linear.z)
            next_angular_x = self.filtered.angular.x + alpha * (target.angular.x - self.filtered.angular.x)
            next_angular_y = self.filtered.angular.y + alpha * (target.angular.y - self.filtered.angular.y)
            next_angular_z = self.filtered.angular.z + alpha * (target.angular.z - self.filtered.angular.z)

            self.filtered.linear.x = self._slew(self.filtered.linear.x, next_linear_x, self.max_linear_step)
            self.filtered.linear.y = self._slew(self.filtered.linear.y, next_linear_y, self.max_linear_step)
            self.filtered.linear.z = self._slew(self.filtered.linear.z, next_linear_z, self.max_linear_step)
            self.filtered.angular.x = self._slew(self.filtered.angular.x, next_angular_x, self.max_angular_step)
            self.filtered.angular.y = self._slew(self.filtered.angular.y, next_angular_y, self.max_angular_step)
            self.filtered.angular.z = self._slew(self.filtered.angular.z, next_angular_z, self.max_angular_step)

        out = TwistStamped()
        out.header.stamp = self.get_clock().now().to_msg()
        out.header.frame_id = self.frame_id
        out.twist = self.filtered
        self.pub.publish(out)


def main() -> None:
    rclpy.init()
    node = SpaceMouseToServo()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    node.destroy_node()
    rclpy.shutdown()


if __name__ == "__main__":
    main()
