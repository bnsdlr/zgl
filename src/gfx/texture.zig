const std = @import("std");
const c = @import("../c.zig");
const gl = c.glad;
const image = c.stb_image;

id: u32,
width: c_int = 0,
height: c_int = 0,
nr_channels: c_int = 0,

const Self = @This();

pub fn new(tex_path: [*:0]const u8) !Self {
    var texture: u32 = 0;
    errdefer gl.glDeleteTextures(1, &texture);
    gl.glGenTextures(1, &texture);
    gl.glBindTexture(gl.GL_TEXTURE_2D, texture);

    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_MIRRORED_REPEAT);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_MIRRORED_REPEAT);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR_MIPMAP_LINEAR);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR);

    var width: c_int = 0;
    var height: c_int = 0;
    var nr_channels: c_int = 0;

    const data: ?[*:0]u8 = image.stbi_load(tex_path, &width, &height, &nr_channels, 0);
    defer image.stbi_image_free(data);

    if (data == null) {
        std.log.err("Failed to load texture \"{s}\" with reason: {s}", .{ tex_path, image.stbi_failure_reason() });
        return error.StbiFailedToLoadImage;
    }

    gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, gl.GL_RGB, width, height, 0, gl.GL_RGB, gl.GL_UNSIGNED_BYTE, data);
    gl.glGenerateMipmap(gl.GL_TEXTURE_2D);

    return .{
        .id = texture,
        .width = width,
        .height = height,
        .nr_channels = nr_channels,
    };
}

pub fn delete(self: *Self) void {
    gl.glDeleteTextures(1, &self.id);
}
