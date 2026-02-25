const std = @import("std");
const builtin = @import("builtin");
const c = @import("c.zig");
const glfw = c.glfw;
const gl = c.glad;
const image = c.stb_image;

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
    const shader: Shader =
        try .construct(@embedFile("assets/shaders/vertex.glsl"), @embedFile("assets/shaders/fragment.glsl"));
    defer gl.glDeleteProgram(shader.id);

    // vertex data and configure vertex attributes
    // const vertices = [_][6]f32{
    //     .{ 0.5, -0.5, 0.0, 1.0, 0.0, 0.0 },
    //     .{ -0.5, -0.5, 0.0, 0.0, 1.0, 0.0 },
    //     .{ 0.0, 0.5, 0.0, 0.0, 0.0, 1.0 },
    // };

    const vertices = [_][8]f32{
        .{ 0.5, 0.5, 0.0, 1.0, 0.0, 0.0, 1.0, 1.0 },
        .{ 0.5, -0.5, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0 },
        .{ -0.5, -0.5, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0 },
        .{ -0.5, 0.5, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0 },
    };

    // const indices = [_][3]u32{
    //     .{ 0, 1, 3 },
    //     .{ 1, 2, 3 },
    // };

    const texture: Texture = try .new("./assets/textures/wall.jpg");

    var vao: u32, var vbo: u32 = .{ 0, 0 };
    defer gl.glDeleteVertexArrays(1, &vao);
    defer gl.glDeleteBuffers(1, &vbo);

    gl.glGenVertexArrays(1, &vao);
    gl.glGenBuffers(1, &vbo);

    gl.glBindVertexArray(vao);

    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, vbo);
    gl.glBufferData(gl.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.GL_STATIC_DRAW);

    // position
    gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 8 * @sizeOf(f32), @ptrFromInt(0));
    gl.glEnableVertexAttribArray(0);
    // color
    gl.glVertexAttribPointer(1, 3, gl.GL_FLOAT, gl.GL_FALSE, 8 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
    gl.glEnableVertexAttribArray(1);
    // texture cords
    gl.glVertexAttribPointer(2, 2, gl.GL_FLOAT, gl.GL_FALSE, 8 * @sizeOf(f32), @ptrFromInt(6 * @sizeOf(f32)));
    gl.glEnableVertexAttribArray(2);

    gl.glBindVertexArray(0);

    shader.use();

    // var ebo: u32 = 0;
    // defer gl.glDeleteBuffers(1, &ebo);
    // gl.glGenBuffers(1, &ebo);
    // gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, ebo);
    // gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, gl.GL_STATIC_DRAW);

    // main loop
    while (glfw.glfwWindowShouldClose(window) == 0) {
        processInput(window);

        gl.glClearColor(0.2, 0.5, 0.5, 1);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);

        // const time_value = glfw.glfwGetTime();
        // const horizontal_offset: f32 = @floatCast(std.math.sin(time_value));
        //
        // shader.setFloat("horizontalOffset", horizontal_offset);

        gl.glBindTexture(gl.GL_TEXTURE_2D, texture.id);
        gl.glBindVertexArray(vao);
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
