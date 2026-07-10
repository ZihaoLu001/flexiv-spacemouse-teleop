"""The two bridge profiles must stay structurally in sync."""

from pathlib import Path

import yaml

CONFIG_DIR = Path(__file__).resolve().parent.parent / "config"


def _params(name, node):
    with open(CONFIG_DIR / name, encoding="utf-8") as f:
        return yaml.safe_load(f)[node]["ros__parameters"]


def test_profiles_have_identical_keys():
    smooth = _params("spacemouse_teleop.yaml", "spacemouse_to_servo")
    fast = _params("spacemouse_teleop.responsive.yaml", "spacemouse_to_servo")
    assert set(smooth) == set(fast), "profiles drifted: add new keys to BOTH files"


def test_responsive_is_lower_latency_not_faster():
    smooth = _params("spacemouse_teleop.yaml", "spacemouse_to_servo")
    fast = _params("spacemouse_teleop.responsive.yaml", "spacemouse_to_servo")
    assert fast["publish_hz"] >= smooth["publish_hz"]
    assert fast["smoothing_alpha"] > smooth["smoothing_alpha"]
    assert fast["max_linear_step"] > smooth["max_linear_step"]
    assert fast["max_angular_step"] > smooth["max_angular_step"]
    for key in ("linear_scale", "linear_y_scale", "angular_scale", "clamp_abs", "deadband"):
        assert fast[key] == smooth[key], f"{key}: responsive must change latency, not speed"
    for key in ("sign_lx", "sign_ly", "sign_lz", "sign_ax", "sign_ay", "sign_az"):
        assert fast[key] == smooth[key], f"{key}: axis calibration must match"


def test_gripper_sections_match():
    smooth = _params("spacemouse_teleop.yaml", "spacemouse_gn01")
    fast = _params("spacemouse_teleop.responsive.yaml", "spacemouse_gn01")
    assert smooth == fast
