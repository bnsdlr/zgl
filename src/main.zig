const std = @import("std");
const zgl = @import("zgl");

pub fn main() void {
    zgl.run() catch |err| switch (err) {
        error.GlfwInitFailed => {
            std.log.err("Failed to initialize glfw!", .{});
            return;
        },
        error.WindowCreationFailed => {
            std.log.err("Failed to create glfw window!", .{});
            return;
        },
        error.GladInitFailed => {
            std.log.err("Failed to initialize glad!", .{});
            return;
        },
        else => {
            return;
        },
    };
}
