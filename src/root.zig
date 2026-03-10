const std = @import("std");
const builtin = @import("builtin");
const c = @import("c.zig");
const glfw = c.glfw;
const gl = c.glad;
const image = c.stb_image;
const glm = @import("glm.zig");

const Matrix4 = glm.Matrix4;
const Vec3 = glm.Vec3;

const Shader = @import("gfx/shader.zig");
const Texture = @import("gfx/texture.zig");

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

pub const stbi_error = error{
    StbiFailedToLoadImage,
};

pub fn run() !void {
    const width = 1080;
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
    glfw.glfwWindowHint(glfw.GLFW_DECORATED, glfw.GLFW_FALSE);

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

    gl.glEnable(gl.GL_DEPTH_TEST);

    // gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE);

    // build and compile shader program
    const shader: Shader = try .construct(
        @embedFile("assets/shaders/vertex.glsl"), 
        @embedFile("assets/shaders/fragment.glsl")
    );
    defer gl.glDeleteProgram(shader.id);

    const vertices = [_][5]f32{
        .{-0.5, -0.5, -0.5,  0.0, 0.0},
        .{ 0.5, -0.5, -0.5,  1.0, 0.0},
        .{ 0.5,  0.5, -0.5,  1.0, 1.0},
        .{ 0.5,  0.5, -0.5,  1.0, 1.0},
        .{-0.5,  0.5, -0.5,  0.0, 1.0},
        .{-0.5, -0.5, -0.5,  0.0, 0.0},

        .{-0.5, -0.5,  0.5,  0.0, 0.0},
        .{ 0.5, -0.5,  0.5,  1.0, 0.0},
        .{ 0.5,  0.5,  0.5,  1.0, 1.0},
        .{ 0.5,  0.5,  0.5,  1.0, 1.0},
        .{-0.5,  0.5,  0.5,  0.0, 1.0},
        .{-0.5, -0.5,  0.5,  0.0, 0.0},

        .{-0.5,  0.5,  0.5,  1.0, 0.0},
        .{-0.5,  0.5, -0.5,  1.0, 1.0},
        .{-0.5, -0.5, -0.5,  0.0, 1.0},
        .{-0.5, -0.5, -0.5,  0.0, 1.0},
        .{-0.5, -0.5,  0.5,  0.0, 0.0},
        .{-0.5,  0.5,  0.5,  1.0, 0.0},

        .{ 0.5,  0.5,  0.5,  1.0, 0.0},
        .{ 0.5,  0.5, -0.5,  1.0, 1.0},
        .{ 0.5, -0.5, -0.5,  0.0, 1.0},
        .{ 0.5, -0.5, -0.5,  0.0, 1.0},
        .{ 0.5, -0.5,  0.5,  0.0, 0.0},
        .{ 0.5,  0.5,  0.5,  1.0, 0.0},
         
        .{-0.5, -0.5, -0.5,  0.0, 1.0},
        .{ 0.5, -0.5, -0.5,  1.0, 1.0},
        .{ 0.5, -0.5,  0.5,  1.0, 0.0},
        .{ 0.5, -0.5,  0.5,  1.0, 0.0},
        .{-0.5, -0.5,  0.5,  0.0, 0.0},
        .{-0.5, -0.5, -0.5,  0.0, 1.0},

        .{-0.5,  0.5, -0.5,  0.0, 1.0},
        .{ 0.5,  0.5, -0.5,  1.0, 1.0},
        .{ 0.5,  0.5,  0.5,  1.0, 0.0},
        .{ 0.5,  0.5,  0.5,  1.0, 0.0},
        .{-0.5,  0.5,  0.5,  0.0, 0.0},
        .{-0.5,  0.5, -0.5,  0.0, 1.0},
    };

    var vao: u32, var vbo: u32 = .{ 0, 0 };
    defer gl.glDeleteVertexArrays(1, &vao);
    defer gl.glDeleteBuffers(1, &vbo);

    gl.glGenVertexArrays(1, &vao);
    gl.glGenBuffers(1, &vbo);

    gl.glBindVertexArray(vao);

    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, vbo);
    gl.glBufferData(gl.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.GL_STATIC_DRAW);

    // position
    gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 5 * @sizeOf(f32), @ptrFromInt(0));
    gl.glEnableVertexAttribArray(0);
    // texture
    gl.glVertexAttribPointer(1, 2, gl.GL_FLOAT, gl.GL_FALSE, 5 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
    gl.glEnableVertexAttribArray(1);

    gl.glBindVertexArray(0);

    shader.use();

    image.stbi_set_flip_vertically_on_load(1);

    const texture_1: Texture = try .init(
        "./assets/textures/wooden_container.jpg", gl.GL_TEXTURE_2D, gl.GL_RGB
    );
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_EDGE);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_EDGE);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_NEAREST);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_NEAREST);
    const texture_2: Texture = try .with_default_opts(
        "./assets/textures/awesomeface.png", gl.GL_TEXTURE_2D, gl.GL_RGBA
    );
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_NEAREST);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_NEAREST);

    gl.glUniform1i(gl.glGetUniformLocation(shader.id, "texture1"), 0);
    gl.glUniform1i(gl.glGetUniformLocation(shader.id, "texture2"), 1);

    // main loop
    while (glfw.glfwWindowShouldClose(window) == 0) {
        processInput(window, &shader);

        gl.glClearColor(0.2, 0.3, 0.3, 1);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);

        gl.glActiveTexture(gl.GL_TEXTURE0);
        gl.glBindTexture(gl.GL_TEXTURE_2D, texture_1.id);
        gl.glActiveTexture(gl.GL_TEXTURE1);
        gl.glBindTexture(gl.GL_TEXTURE_2D, texture_2.id);

        gl.glUniform1f(gl.glGetUniformLocation(shader.id, "mixPercentage"), curr_mix);

        var model = glm.identity(1);
        model.applyRotation(@as(f32, @floatCast(glfw.glfwGetTime())) * std.math.degreesToRadians(50), .{ .x = 0.5, .y = 1 });
        var view = glm.identity(1);
        view.applyTranslation(Vec3 {0, 0, -3});
        var proj = glm.perspective(std.math.degreesToRadians(45), width / height, 0.1, 100);
        // var proj = glm.ortho(0, width, 0, height, 0.1, 100);

        gl.glUniformMatrix4fv(gl.glGetUniformLocation(shader.id, "model"), 1, gl.GL_TRUE, model.elementPtr());
        gl.glUniformMatrix4fv(gl.glGetUniformLocation(shader.id, "view"), 1, gl.GL_TRUE, view.elementPtr());
        gl.glUniformMatrix4fv(gl.glGetUniformLocation(shader.id, "projection"), 1, gl.GL_TRUE, proj.elementPtr());

        gl.glBindVertexArray(vao);

        gl.glDrawArrays(gl.GL_TRIANGLES, 0, 36);

        gl.glBindVertexArray(0);

        glfw.glfwSwapBuffers(window);
        glfw.glfwPollEvents();
    }
}

var curr_mix: f32 = 0.5;

fn processInput(window: Window, shader_ptr: *const Shader) void {
    if (glfw.glfwGetKey(window, glfw.GLFW_KEY_ESCAPE) == glfw.GLFW_PRESS) {
        glfw.glfwSetWindowShouldClose(window, 1);
    }

    if (glfw.glfwGetKey(window, glfw.GLFW_KEY_UP) == glfw.GLFW_PRESS) {
        if (curr_mix < 1.0) curr_mix += 0.01;
        gl.glUniform1f(gl.glGetUniformLocation(shader_ptr.id, "mixPercentage"), curr_mix);
    }

    if (glfw.glfwGetKey(window, glfw.GLFW_KEY_DOWN) == glfw.GLFW_PRESS) {
        if (curr_mix > 0.0) curr_mix -= 0.01;
        gl.glUniform1f(gl.glGetUniformLocation(shader_ptr.id, "mixPercentage"), curr_mix);
    }
}

fn framebufferSizeCallback(_: Window, width: c_int, height: c_int) callconv(.c) void {
    // std.debug.print("Window size updated: (width: {d}, height: {d})\n", .{ width, height });
    gl.glViewport(0, 0, width, height);
}
