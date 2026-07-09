"""Unit tests for the pure logic in the bridge nodes (no ROS spin needed)."""

from types import SimpleNamespace

from flexiv_spacemouse_teleop.spacemouse_gn01 import SpaceMouseGN01
from flexiv_spacemouse_teleop.spacemouse_to_servo import SpaceMouseToServo

apply_ = SpaceMouseToServo._apply
slew_ = SpaceMouseToServo._slew
rising_edge_ = SpaceMouseGN01._rising_edge


def bridge(deadband=0.1, clamp_abs=0.5):
    return SimpleNamespace(deadband=deadband, clamp_abs=clamp_abs)


def test_apply_zeroes_inside_deadband():
    assert apply_(bridge(), 0.05, 1.0, 1.0) == 0.0
    assert apply_(bridge(), -0.09, 1.0, 1.0) == 0.0


def test_apply_scales_and_signs():
    assert apply_(bridge(), 0.2, 1.5, 1.0) == 0.2 * 1.5
    assert apply_(bridge(), 0.2, 1.5, -1.0) == -0.2 * 1.5


def test_apply_clamps_both_directions():
    assert apply_(bridge(), 1.0, 2.0, 1.0) == 0.5
    assert apply_(bridge(), 1.0, 2.0, -1.0) == -0.5


def test_slew_limits_step():
    assert slew_(None, 0.0, 1.0, max_step=0.1) == 0.1
    assert slew_(None, 0.0, -1.0, max_step=0.1) == -0.1
    assert slew_(None, 0.0, 0.05, max_step=0.1) == 0.05


def gn01(prev):
    return SimpleNamespace(prev_buttons=prev)


def test_rising_edge_fires_only_on_transition():
    assert rising_edge_(gn01([0, 0]), [1, 0], 0) is True
    assert rising_edge_(gn01([1, 0]), [1, 0], 0) is False
    assert rising_edge_(gn01([1, 0]), [0, 0], 0) is False


def test_rising_edge_out_of_range_is_safe():
    assert rising_edge_(gn01([0, 0]), [1, 0], -1) is False
    assert rising_edge_(gn01([0]), [1, 1], 1) is False
