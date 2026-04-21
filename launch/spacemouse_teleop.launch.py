from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node

import os


def generate_launch_description():
    share_dir = get_package_share_directory("flexiv_spacemouse_teleop")
    default_config = os.path.join(share_dir, "config", "spacemouse_teleop.yaml")

    config_file = LaunchConfiguration("config_file")
    servo_twist_topic = LaunchConfiguration("servo_twist_topic")
    frame_id = LaunchConfiguration("frame_id")
    enable_gripper = LaunchConfiguration("enable_gripper")
    start_spacenav_node = LaunchConfiguration("start_spacenav_node")

    return LaunchDescription(
        [
            DeclareLaunchArgument(
                "config_file",
                default_value=default_config,
                description="YAML parameter file for the SpaceMouse bridge nodes.",
            ),
            DeclareLaunchArgument(
                "servo_twist_topic",
                default_value="/servo_node/delta_twist_cmds",
                description="MoveIt Servo Cartesian twist command topic.",
            ),
            DeclareLaunchArgument(
                "frame_id",
                default_value="",
                description="TwistStamped frame_id. Empty uses MoveIt Servo default.",
            ),
            DeclareLaunchArgument(
                "enable_gripper",
                default_value="true",
                description="Start the SpaceMouse button to GN01 gripper bridge.",
            ),
            DeclareLaunchArgument(
                "start_spacenav_node",
                default_value="true",
                description="Start spacenav_node from this launch file.",
            ),
            Node(
                package="spacenav",
                executable="spacenav_node",
                name="spacenav",
                output="screen",
                condition=IfCondition(start_spacenav_node),
            ),
            Node(
                package="flexiv_spacemouse_teleop",
                executable="spacemouse_to_servo",
                name="spacemouse_to_servo",
                output="screen",
                parameters=[
                    config_file,
                    {
                        "output_topic": servo_twist_topic,
                        "frame_id": frame_id,
                    },
                ],
            ),
            Node(
                package="flexiv_spacemouse_teleop",
                executable="spacemouse_gn01",
                name="spacemouse_gn01",
                output="screen",
                parameters=[config_file],
                condition=IfCondition(enable_gripper),
            ),
        ]
    )

