from glob import glob

from setuptools import setup

package_name = "flexiv_spacemouse_teleop"

setup(
    name=package_name,
    version="0.1.0",
    packages=[package_name],
    data_files=[
        ("share/ament_index/resource_index/packages", ["resource/" + package_name]),
        ("share/" + package_name, ["package.xml"]),
        ("share/" + package_name + "/launch", glob("launch/*.launch.py")),
        ("share/" + package_name + "/config", glob("config/*.yaml")),
    ],
    install_requires=["setuptools"],
    zip_safe=True,
    maintainer="Zihao Lu",
    maintainer_email="181958768+ZihaoLu001@users.noreply.github.com",
    description="SpaceMouse teleop bridge for Flexiv Rizon with MoveIt Servo",
    license="MIT",
    entry_points={
        "console_scripts": [
            "spacemouse_to_servo = flexiv_spacemouse_teleop.spacemouse_to_servo:main",
            "spacemouse_gn01 = flexiv_spacemouse_teleop.spacemouse_gn01:main",
            "save_start_state = flexiv_spacemouse_teleop.save_start_state:main",
            "return_to_joint_state = flexiv_spacemouse_teleop.return_to_joint_state:main",
        ],
    },
)
