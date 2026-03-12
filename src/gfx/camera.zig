const std = @import("std");
const math = std.math;
const glm = @import("../glm.zig");

const Vec3 = glm.Vec3;

const CameraMovement = enum {
    forward,
    backward,
    up,
    down,
    left,
    right,
};

const Self = @This();

pos: Vec3 = .{0, 0, 3},
front: Vec3 = .{0, 0, -1},
up: Vec3 = .{0, 1, 0},
right: Vec3 = .{0, 1, 0},
world_up: Vec3 = .{0, 1, 0},

angles: EulerAngles = .{},
opts: Options = .{},
    
const EulerAngles = struct {
    yaw: f32 = -90,
    pitch: f32 = 0,
};

const Options = struct {
    movement_speed: f32 = 2.5,
    mouse_sensitivity: f32 = 0.1,
    zoom: f32 = 45,
    min_zoom: f32 = 1,
    max_zoom: f32 = 100,
};

pub fn default() Self {
    var new: Self = .{};
    updateVectors(&new);
    return new;
}

pub fn init(pos: ?Vec3, up: ?Vec3, angles: EulerAngles, options: Options) Self {
    var new: Self = .{
        .angles = angles,
        .opts = options,
    };
    if (pos != null) new.pos = pos.?;
    if (up != null) new.world_up = up.?;
    updateVectors(&new);
    return new;
}

pub fn getViewMatrix(self: *const Self) glm.Matrix4 {
    return glm.lookAt(
        self.pos,
        self.pos + self.front,
        self.up
    ); 
}

pub fn processMovement(self: *Self, movement: CameraMovement, delta_time: f64) void {
    const velocity: Vec3 = @splat(@floatCast(self.opts.movement_speed * delta_time));

    switch (movement) {
        .backward => self.pos -= self.front * velocity,
        .forward => self.pos += self.front * velocity,
        .up => self.pos += self.up * velocity,
        .down => self.pos -= self.up * velocity,
        .left => self.pos -= self.right * velocity,
        .right => self.pos += self.right * velocity,
    }
}

pub fn processMouseMovement(self: *Self, x_offset: f32, y_offset: f32, constrain_pitch: bool) void {
    const offset_x = x_offset * self.opts.mouse_sensitivity;
    const offset_y = y_offset * self.opts.mouse_sensitivity;

    self.angles.yaw += offset_x;
    self.angles.pitch += offset_y;

    if (constrain_pitch) {
        if (self.angles.pitch > 89) {
            self.angles.pitch = 89;
        } else if (self.angles.pitch < -89) {
            self.angles.pitch = -89;
        }
    }

    self.updateVectors();
}

pub fn processMouseScroll(self: *Self, y_offset: f32) void {
    self.opts.zoom -= y_offset;
    if (self.opts.zoom < self.opts.min_zoom) {
        self.opts.zoom = self.opts.min_zoom;
    } else if (self.opts.zoom > self.opts.max_zoom) {
        self.opts.zoom = self.opts.max_zoom;
    }
}

fn updateVectors(self: *Self) void {
    var direction: Vec3 = .{
        @floatCast(math.cos(math.degreesToRadians(self.angles.yaw)) * math.cos(math.degreesToRadians(self.angles.pitch))),
        @floatCast(math.sin(math.degreesToRadians(self.angles.pitch))),
        @floatCast(math.sin(math.degreesToRadians(self.angles.yaw)) * math.cos(math.degreesToRadians(self.angles.pitch))),
    };
    glm.normalize(&direction);
    self.front = direction;

    self.right = glm.normalized(glm.cross(self.front, self.world_up));
    self.up = glm.normalized(glm.cross(self.right, self.front));
}
