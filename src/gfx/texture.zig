const std = @import("std");
const c = @import("../c.zig");
const gl = c.glad;
const image = c.stb_image;

id: u32,
width: c_int = 0,
height: c_int = 0,
nr_channels: c_int = 0,
kind: gl.GLenum,

const Self = @This();

/// Creates a new texture, 
pub fn init(tex_path: [*:0]const u8, tex_kind: gl.GLenum, color_encoding: gl.GLenum) !Self {
    var tex: Self = .{ .id = 0, .kind = tex_kind };
    errdefer gl.glDeleteTextures(1, &tex.id);
    gl.glGenTextures(1, &tex.id);
    gl.glBindTexture(gl.GL_TEXTURE_2D, tex.id);

    const data: ?[*:0]u8 = image.stbi_load(tex_path, &tex.width, &tex.height, &tex.nr_channels, 0);
    defer image.stbi_image_free(data);

    if (data == null) {
        std.log.err("Failed to load texture \"{s}\" with reason: {s}", .{ 
            tex_path, 
            image.stbi_failure_reason() 
        });
        return error.StbiFailedToLoadImage;
    }

    gl.glTexImage2D(
        tex.kind, 0, gl.GL_RGB, tex.width, tex.height,
        0, color_encoding, gl.GL_UNSIGNED_BYTE, data
    );
    gl.glGenerateMipmap(tex_kind);

    return tex;
}

pub fn with_default_opts(tex_path: [*:0]const u8, tex_kind: gl.GLenum, color_encoding: gl.GLenum) !Self {
    const tex: Self = try .init(tex_path, tex_kind, color_encoding);

    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_MIRRORED_REPEAT);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_MIRRORED_REPEAT);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR_MIPMAP_LINEAR);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR);

    return tex;
}

pub fn delete(self: *Self) void {
    gl.glDeleteTextures(1, &self.id);
}
