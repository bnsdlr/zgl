const std = @import("std");
const builtin = @import("builtin");
const c = @import("c.zig");
const glfw = c.glfw;
const gl = c.glad;

const Window = c.Window;

pub const glfw_error = error{
    GlfwInitFailed,
    WindowCreationFailed,
};

pub const glad_error = error{
    GladInitFailed,
    ShaderCompilationFailed,
    ShaderLinkingFailed,
};

pub fn run() (glad_error || glfw_error)!void {
    const width = 1920;
    const height = 1080;
    const title = "zgl";

    // glfw initialization
    if (glfw.glfwInit() == 0) {
        return glfw_error.GlfwInitFailed;
    }
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);

    if (builtin.os.tag == .macos) {
        glfw.glfwWindowHint(glfw.GLFW_OPENGL_FORWARD_COMPAT, glfw.GLFW_TRUE);
    }

    // glfw window creation
    const window: Window = glfw.glfwCreateWindow(width, height, title, null, null);
    if (window == null) {
        glfw.glfwTerminate();
        return glfw_error.WindowCreationFailed;
    }
    defer glfw.glfwDestroyWindow(window);

    glfw.glfwMakeContextCurrent(window);
    glfw.glfwSwapInterval(1);

    // glad load all OpenGL function pointers
    const loader: gl.GLADloadproc = @ptrCast(&glfw.glfwGetProcAddress);

    if (gl.gladLoadGLLoader(loader) == 0) {
        return glad_error.GladInitFailed;
    }

    _ = glfw.glfwSetFramebufferSizeCallback(window, &framebufferSizeCallback);

    // gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE);

    // build and compile shader program
    var success: c_int = 0;
    var info_log_length: u32 = 0;
    var info_log: [512]u8 = undefined;

    // vertex shader
    const vs_src: [*c]const u8 = @embedFile("assets/shaders/vertex.glsl");
    const vertex_shader: u32 =
        getCompiledShader(vs_src, &success, &info_log_length, gl.GL_VERTEX_SHADER);
    defer gl.glDeleteShader(vertex_shader);

    if (success == 0) {
        gl.glGetShaderInfoLog(vertex_shader, info_log.len, null, &info_log);
        std.log.err("Failed to compile vertex shader:\n{s}", .{info_log[0..info_log_length]});
        return glad_error.ShaderCompilationFailed;
    }

    // fragment shader
    const fs_src: [*c]const u8 = @embedFile("assets/shaders/fragment.glsl");
    const fragment_shader: u32 =
        getCompiledShader(fs_src, &success, &info_log_length, gl.GL_FRAGMENT_SHADER);
    defer gl.glDeleteShader(fragment_shader);

    if (success == 0) {
        gl.glGetShaderInfoLog(fragment_shader, info_log.len, null, &info_log);
        std.log.err("Failed to compile fragment shader:\n{s}", .{info_log[0..info_log_length]});
        return glad_error.ShaderCompilationFailed;
    }

    // shader program
    const shader_program: u32 = gl.glCreateProgram();
    defer gl.glDeleteProgram(shader_program);

    gl.glAttachShader(shader_program, vertex_shader);
    gl.glAttachShader(shader_program, fragment_shader);
    gl.glLinkProgram(shader_program);

    gl.glGetProgramiv(shader_program, gl.GL_LINK_STATUS, &success);
    // gl.glGetProgramiv(shader_program, gl.GL_INFO_LOG_LENGTH, &info_log_length);

    if (success == 0) {
        gl.glGetProgramInfoLog(shader_program, info_log.len, null, &info_log);
        std.log.err("Failed to link shaders:\n{s}", .{info_log[0..info_log_length]});
        return glad_error.ShaderLinkingFailed;
    }

    const fs2_src = @embedFile("assets/shaders/fragment2.glsl");
    const fs2 = getCompiledShader(fs2_src, &success, &info_log_length, gl.GL_FRAGMENT_SHADER);
    defer gl.glDeleteShader(fs2);

    if (success == 0) {
        gl.glGetShaderInfoLog(fs2, info_log.len, null, &info_log);
        std.log.err("Failed to compile fragment shader 2:\n{s}", .{info_log[0..info_log_length]});
        return glad_error.ShaderCompilationFailed;
    }

    const shader_program2: u32 = gl.glCreateProgram();
    defer gl.glDeleteProgram(shader_program2);

    gl.glAttachShader(shader_program2, vertex_shader);
    gl.glAttachShader(shader_program2, fs2);
    gl.glLinkProgram(shader_program2);

    gl.glGetProgramiv(shader_program2, gl.GL_LINK_STATUS, &success);

    if (success == 0) {
        gl.glGetProgramInfoLog(shader_program, info_log.len, null, &info_log);
        std.log.err("Failed to link shaders:\n{s}", .{info_log[0..info_log_length]});
        return glad_error.ShaderLinkingFailed;
    }

    // vertex data and configure vertex attributes
    const vertices1 = [_][3]f32{
        .{ 0.5, 0.5, 0.0 },
        .{ -0.5, 0.5, 0.0 },
        .{ -1.0, -0.5, 0.0 },
    };
    const vertices2 = [_][3]f32{
        .{ 0.5, 0.5, 0.0 },
        .{ 0.5, -0.5, 0.0 },
        // .{ -0.5, -0.5, 0.0 },
        .{ -0.5, 0.5, 0.0 },
    };

    // const indices = [_][3]u32{
    //     .{ 0, 1, 3 },
    //     .{ 1, 2, 3 },
    // };

    // buff 1
    var vao1: u32 = 0;
    defer gl.glDeleteVertexArrays(1, &vao1);
    gl.glGenVertexArrays(1, &vao1);
    gl.glBindVertexArray(vao1);

    var vbo1: u32 = 0;
    defer gl.glDeleteBuffers(1, &vbo1);
    gl.glGenBuffers(1, &vbo1);
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, vbo1);
    gl.glBufferData(gl.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices1)), &vertices1, gl.GL_STATIC_DRAW);

    gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 3 * @sizeOf(f32), @ptrFromInt(0));
    gl.glEnableVertexAttribArray(0);

    // var ebo: u32 = 0;
    // defer gl.glDeleteBuffers(1, &ebo);
    // gl.glGenBuffers(1, &ebo);
    // gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, ebo);
    // gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, gl.GL_STATIC_DRAW);

    var vao2: u32 = 0;
    defer gl.glDeleteVertexArrays(1, &vao2);
    gl.glGenVertexArrays(1, &vao2);
    gl.glBindVertexArray(vao2);

    var vbo2: u32 = 0;
    defer gl.glDeleteBuffers(1, vbo2);
    gl.glGenBuffers(1, &vbo2);
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, vbo2);
    gl.glBufferData(gl.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices2)), &vertices2, gl.GL_STATIC_DRAW);

    gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 3 * @sizeOf(f32), @ptrFromInt(0));
    gl.glEnableVertexAttribArray(0);

    // main loop
    while (glfw.glfwWindowShouldClose(window) == 0) {
        processInput(window);

        gl.glClearColor(0.2, 0.5, 0.5, 1);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);

        gl.glUseProgram(shader_program);
        gl.glBindVertexArray(vao1);
        gl.glDrawArrays(gl.GL_TRIANGLES, 0, 3);
        // gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, ebo);
        // gl.glDrawElements(gl.GL_TRIANGLES, indices.len * indices[0].len, gl.GL_UNSIGNED_INT, @ptrFromInt(0));

        gl.glUseProgram(shader_program2);
        gl.glBindVertexArray(vao2);
        gl.glDrawArrays(gl.GL_TRIANGLES, 0, 3);

        gl.glBindVertexArray(0);

        glfw.glfwSwapBuffers(window);
        glfw.glfwPollEvents();
    }
}

fn processInput(window: Window) void {
    if (glfw.glfwGetKey(window, glfw.GLFW_KEY_ESCAPE) == glfw.GLFW_PRESS) {
        glfw.glfwSetWindowShouldClose(window, 1);
    }
}

fn framebufferSizeCallback(_: Window, width: c_int, height: c_int) callconv(.c) void {
    // std.debug.print("Window size updated: (width: {d}, height: {d})\n", .{ width, height });
    gl.glViewport(0, 0, width, height);
}

fn getCompiledShader(src: [*c]const u8, success: *c_int, info_log_length: *u32, kind: gl.GLenum) u32 {
    var log_len: c_int = 0;
    const shader: u32 = gl.glCreateShader(kind);
    gl.glShaderSource(shader, 1, &src, null);
    gl.glCompileShader(shader);
    gl.glGetShaderiv(shader, gl.GL_COMPILE_STATUS, success);
    gl.glGetShaderiv(shader, gl.GL_INFO_LOG_LENGTH, &log_len);

    info_log_length.* = if (log_len >= 0) @intCast(log_len) else 0;

    return shader;
}
