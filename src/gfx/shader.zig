const std = @import("std");
const c = @import("../c.zig");
const gl = c.glad;

const Matrix = @import("../glm.zig").matrices.Matrix;

id: u32 = 0,

const Self = @This();

pub fn construct(vertex_shader_code: [*:0]const u8, fragment_shader_code: [*:0]const u8) !Self {
    var success: c_int = 0;
    var info_log_length: u32 = 0;
    var info_log: [512]u8 = undefined;

    const vertex_shader: u32 =
        loadShader(vertex_shader_code, gl.GL_VERTEX_SHADER, &success, &info_log_length);
    defer gl.glDeleteShader(vertex_shader);

    if (success == 0) {
        gl.glGetShaderInfoLog(vertex_shader, info_log.len, null, &info_log);
        std.log.err("Failed to compile vertex shader:\n{s}", .{info_log[0..info_log_length]});
        return error.ShaderCompilationFailed;
    }

    const fragment_shader: u32 =
        loadShader(fragment_shader_code, gl.GL_FRAGMENT_SHADER, &success, &info_log_length);
    defer gl.glDeleteShader(fragment_shader);

    if (success == 0) {
        gl.glGetShaderInfoLog(fragment_shader, info_log.len, null, &info_log);
        std.log.err("Failed to compile fragment shader:\n{s}", .{info_log[0..info_log_length]});
        return error.ShaderCompilationFailed;
    }

    const program: u32 = gl.glCreateProgram();
    gl.glAttachShader(program, vertex_shader);
    gl.glAttachShader(program, fragment_shader);
    gl.glLinkProgram(program);
    gl.glGetProgramiv(program, gl.GL_LINK_STATUS, &success);
    gl.glGetProgramiv(program, gl.GL_INFO_LOG_LENGTH, @ptrCast(&info_log_length));

    if (success == 0) {
        gl.glGetProgramInfoLog(program, info_log.len, null, &info_log);
        std.log.err("Failed to link shader program:\n{s}", .{info_log[0..info_log_length]});
        return error.ShaderLinkingFailed;
    }

    return Self{ .id = program };
}

fn loadShader(code: [*:0]const u8, kind: gl.GLenum, success: *c_int, info_log_length: *u32) u32 {
    // var info_log_len: c_int = 0;
    const shader: u32 = gl.glCreateShader(kind);
    gl.glShaderSource(shader, 1, &code, null);
    gl.glCompileShader(shader);
    gl.glGetShaderiv(shader, gl.GL_COMPILE_STATUS, success);
    gl.glGetShaderiv(shader, gl.GL_INFO_LOG_LENGTH, @ptrCast(info_log_length));

    // if (info_log_len > 0) {
    //     info_log_length.* = info_log_len;
    // }

    return shader;
}

/// use/activate the shader
pub fn use(self: *const Self) void {
    gl.glUseProgram(self.id);
}

pub fn setBool(self: *const Self, name: [*:0]const u8, value: bool) void {
    gl.glUniform1i(gl.glGetUniformLocation(self.id, name), @bitCast(value));
}

pub fn setInt(self: *const Self, name: [*:0]const u8, value: c_int) void {
    gl.glUniform1i(gl.glGetUniformLocation(self.id, name), value);
}

pub fn setFloat(self: *const Self, name: [*:0]const u8, value: f32) void {
    gl.glUniform1f(gl.glGetUniformLocation(self.id, name), value);
}

pub fn setVec2(self: *const Self, name: [*:0]const u8, x: f32, y: f32) void {
    gl.glUniform2fv(gl.glGetUniformLocation(self.id, name), x, y);
}

pub fn setVec3(self: *const Self, name: [*:0]const u8, x: f32, y: f32, z: f32) void {
    gl.glUniform3fv(gl.glGetUniformLocation(self.id, name), x, y, z);
}

pub fn setVec4(self: *const Self, name: [*:0]const u8, x: f32, y: f32, z: f32, w: f32) void {
    gl.glUniform4fv(gl.glGetUniformLocation(self.id, name), x, y, z, w);
}

pub fn setMat2(self: *const Self, name: [*:0]const u8, matrix: Matrix(f32, 2, 2)) void {
    gl.glUniformMatrix2fv(gl.glGetUniformLocation(self.id, name), 1, gl.GL_TRUE, matrix.elementPtr());
}

pub fn setMat3(self: *const Self, name: [*:0]const u8, matrix: Matrix(f32, 3, 3)) void {
    gl.glUniformMatrix3fv(gl.glGetUniformLocation(self.id, name), 1, gl.GL_TRUE, matrix.elementPtr());
}

pub fn setMat4(self: *const Self, name: [*:0]const u8, matrix: Matrix(f32, 4, 4)) void {
    gl.glUniformMatrix4fv(gl.glGetUniformLocation(self.id, name), 1, gl.GL_TRUE, matrix.elementPtr());
}
