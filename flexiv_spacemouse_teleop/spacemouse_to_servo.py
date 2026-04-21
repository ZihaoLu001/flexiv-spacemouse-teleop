#!/usr/bin/env python3
"""Bridge SpaceMouse twist input to MoveIt Servo TwistStamped commands."""

from __future__ import annotations

import rclpy
from geometry_msgs.msg import Twist, TwistStamped
from rclpy.node import Node


class SpaceMouseToServo(Node):
    def __init__(self) -> None:
        super().__init__("spacemouse_to_servo")

        self.declare_parameter("input_topic", "/spacenav/twist")
        self.declare_parameter("output_topic", "/servo_node/delta_twist_cmds")
        self.declare_parameter("publish_hz", 50.0)
        self.declare_parameter("frame_id", "")
        self.declare_parameter("input_timeout", 0.25)

        # MoveIt Servo config in flexiv_ros2 humble-v1.7 uses unitless commands.
        self.declare_parameter("linear_scale", 0.20)
        self.declare_parameter("angular_scale", 0.40)
        self.declare_parameter("deadband", 0.02)
        self.declare_parameter("clamp_abs", 1.0)

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
        self.linear_scale = float(self.get_parameter("linear_scale").value)
        self.angular_scale = float(self.get_parameter("angular_scale").value)
        self.deadband = float(self.get_parameter("deadband").value)
        self.clamp_abs = abs(float(self.get_parameter("clamp_abs").value))

        self.sign_lx = float(self.get_parameter("sign_lx").value)
        self.sign_ly = float(self.get_parameter("sign_ly").value)
        self.sign_lz = float(self.get_parameter("sign_lz").value)
        self.sign_ax = float(self.get_parameter("sign_ax").value)
        self.sign_ay = float(self.get_parameter("sign_ay").value)
        self.sign_az = float(self.get_parameter("sign_az").value)

        self.latest = Twist()
        self.last_input_time = None

        self.create_subscription(Twist, self.input_topic, self.twist_cb, 10)
        self.pub = self.create_publisher(TwistStamped, self.output_topic, 10)
        self.create_timer(1.0 / self.publish_hz, self.timer_cb)

        self.get_logger().info(
            f"Publishing SpaceMouse twist to {self.output_topic} at {self.publish_hz:.1f} Hz"
        )

    def _apply(self, value: float, scale: float, sign: float) -> float:
        if abs(value) < self.deadband:
            return 0.0
        scaled = sign * scale * value
        return max(-self.clamp_abs, min(self.clamp_abs, scaled))

    def twist_cb(self, msg: Twist) -> None:
        self.latest = msg
        self.last_input_time = self.get_clock().now()

    def _input_is_stale(self) -> bool:
        if self.last_input_time is None:
            return True
        age = (self.get_clock().now() - self.last_input_time).nanoseconds * 1e-9
        return age > self.input_timeout

    def timer_cb(self) -> None:
        msg = Twist() if self._input_is_stale() else self.latest

        out = TwistStamped()
        out.header.stamp = self.get_clock().now().to_msg()
        out.header.frame_id = self.frame_id
        out.twist.linear.x = self._apply(msg.linear.x, self.linear_scale, self.sign_lx)
        out.twist.linear.y = self._apply(msg.linear.y, self.linear_scale, self.sign_ly)
        out.twist.linear.z = self._apply(msg.linear.z, self.linear_scale, self.sign_lz)
        out.twist.angular.x = self._apply(msg.angular.x, self.angular_scale, self.sign_ax)
        out.twist.angular.y = self._apply(msg.angular.y, self.angular_scale, self.sign_ay)
        out.twist.angular.z = self._apply(msg.angular.z, self.angular_scale, self.sign_az)
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

