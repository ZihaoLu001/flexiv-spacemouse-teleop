from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    config_file = LaunchConfiguration("config_file")
    namespace = LaunchConfiguration("namespace")

    return LaunchDescription([
        DeclareLaunchArgument(
            "config_file",
            default_value=PathJoinSubstitution([
                FindPackageShare("flexiv_spacemouse_teleop"),
                "config",
                "zed2i_v4l2.yaml",
            ]),
            description="YAML config for the ZED 2i UVC/V4L2 RGB stream.",
        ),
        DeclareLaunchArgument(
            "namespace",
            default_value="zed2i",
            description="ROS namespace for camera topics.",
        ),
        Node(
            package="v4l2_camera",
            executable="v4l2_camera_node",
            name="rgb_camera",
            namespace=namespace,
            output="screen",
            parameters=[config_file],
        ),
    ])
