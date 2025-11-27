const std = @import("std");

const c = @import("c.zig").c;

const input_event = @import("input-event.zig");
const InputChannel = input_event.InputChannel;

const kernel = @import("../kernel.zig");
const SignedCell = kernel.SignedCell;

// ===

const Gamepad = struct {
    is_connected: bool,
    last_state: c.GLFWgamepadstate,
    current_state: c.GLFWgamepadstate,

    fn rememberState(self: *@This()) void {
        @memcpy(&self.last_state.buttons, &self.current_state.buttons);
        @memcpy(&self.last_state.axes, &self.current_state.axes);
    }
};

var gamepads: [16]Gamepad = undefined;

pub fn onConnectionChange(index: usize, is_connected: bool) void {
    var gamepad = &gamepads[index];

    gamepad.is_connected = is_connected;
    if (gamepad.is_connected) {
        // TODO test for error
        _ = c.glfwGetGamepadState(@intCast(index), &gamepad.current_state);
        gamepad.rememberState();
    }
}

pub fn init() void {
    for (0..gamepads.len) |i| {
        const is_joystick_connected = c.glfwJoystickPresent(@intCast(i)) == c.GLFW_TRUE;
        const is_joystick_gamepad = c.glfwJoystickIsGamepad(@intCast(i)) == c.GLFW_TRUE;
        if (is_joystick_connected and is_joystick_gamepad) {
            onConnectionChange(i, true);
        }
    }
}

pub fn poll(input_channel: *InputChannel) void {
    for (&gamepads, 0..) |*gamepad, i| {
        if (gamepad.is_connected) {
            // TODO test for error
            _ = c.glfwGetGamepadState(@intCast(i), &gamepad.current_state);

            for (gamepad.current_state.buttons, 0..) |curr, j| {
                if (curr != gamepad.last_state.buttons[j]) {
                    input_channel.push(.{
                        .gamepad = .{
                            .index = @intCast(i),
                            .button = @intCast(j),
                            .action = curr,
                        },
                    });
                }
            }

            for (gamepad.current_state.axes, 0..) |curr, j| {
                if (curr != gamepad.last_state.axes[j]) {
                    const action: SignedCell = @intFromFloat(curr * std.math.maxInt(SignedCell));
                    input_channel.push(.{
                        .gamepad = .{
                            .index = @intCast(i),
                            .button = @intCast(j + c.GLFW_GAMEPAD_BUTTON_LAST + 1),
                            .action = action,
                        },
                    });
                }
            }

            gamepad.rememberState();
        }
    }
}
