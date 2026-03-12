const std = @import("std");
const builtin = @import("builtin");
const c = @import("c.zig");
const glfw = c.glfw;
const gl = c.glad;
const image = c.stb_image;
const glm = @import("glm.zig");

const math = std.math;

const Rotation = glm.matrices.Rotation;
const Matrix4 = glm.Matrix4;
const Vec3 = glm.Vec3;

const Shader = @import("gfx/shader.zig");
const Texture = @import("gfx/texture.zig");
const Camera = @import("gfx/camera.zig");

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

const src_width = 1080;
const src_height = 1080;

var width: c_int = src_width;
var height: c_int = src_height;
var title = "zgl";

var delta_time: f64 = 0;
var last_frame: f64 = 0;

var camera: Camera = .init(.{0, 0, 3}, .{0, 1, 0}, .{}, .{ .movement_speed = 3 });

var last_mouse_x: f32 = @floatFromInt(@divTrunc(src_width, @as(c_int, 2)));
var last_mouse_y: f32 = @floatFromInt(@divTrunc(src_height, @as(c_int, 2)));
var first_mouse = true;

pub fn run() !void {
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
    _ = glfw.glfwSetCursorPosCallback(window, &cursorPosCallback);
    _ = glfw.glfwSetScrollCallback(window, &srcollCallback);
    glfw.glfwSetInputMode(window, glfw.GLFW_CURSOR, glfw.GLFW_CURSOR_DISABLED);

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

    const cube_positions = [_]Vec3{
        Vec3{ 0.0,  0.0,  0.0}, 
        Vec3{ 2.0,  5.0, -15.0}, 
        Vec3{-1.5, -2.2, -2.5},  
        Vec3{-3.8, -2.0, -12.3},  
        Vec3{ 2.4, -0.4, -3.5},  
        Vec3{-1.7,  3.0, -7.5},  
        Vec3{ 1.3, -2.0, -2.5},  
        Vec3{ 1.5,  2.0, -2.5}, 
        Vec3{ 1.5,  0.2, -1.5}, 
        Vec3{-1.3,  1.0, -1.5}  
    };

    // var cube_positions: [10000]Vec3 = undefined;
    //
    // const rand = std.crypto.random;
    //
    // const max = 100;
    // const min = -100;
    //
    // for (0..cube_positions.len) |i| {
    //     const r1 = rand.float(f32) * (max - min) + min;
    //     const r2 = rand.float(f32) * (max - min) + min;
    //     const r3 = rand.float(f32) * (max - min) + min;
    //     cube_positions[i] = Vec3{r1, r2, r3};
    // }

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
        const current_time = glfw.glfwGetTime();
        delta_time = current_time - last_frame;
        last_frame = current_time;
        processInput(window);

        gl.glClearColor(0.2, 0.3, 0.3, 1);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);

        gl.glActiveTexture(gl.GL_TEXTURE0);
        gl.glBindTexture(gl.GL_TEXTURE_2D, texture_1.id);
        gl.glActiveTexture(gl.GL_TEXTURE1);
        gl.glBindTexture(gl.GL_TEXTURE_2D, texture_2.id);

        gl.glBindVertexArray(vao);

        var proj = glm.perspective(std.math.degreesToRadians(camera.opts.zoom), @as(f32, @floatFromInt(@divTrunc(width, height))), 0.1, 100);
        gl.glUniformMatrix4fv(gl.glGetUniformLocation(shader.id, "projection"), 1, gl.GL_TRUE, proj.elementPtr());

        var view = camera.getViewMatrix();
        gl.glUniformMatrix4fv(gl.glGetUniformLocation(shader.id, "view"), 1, gl.GL_TRUE, view.elementPtr());

        for (0..cube_positions.len) |i| {
            var model = glm.identity(1);
            // const deg: f32 = if (i % 2 == 0) -50 else 50;
            // model.applyRotation(
            //     @as(f32, @floatCast(glfw.glfwGetTime())) * std.math.degreesToRadians(deg) 
            //     + @as(f32, @floatFromInt(i)) * (360 / cube_positions.len), .{ .x = 0.5, .y = 1 });
            model.applyTranslation(cube_positions[i]);

            gl.glUniformMatrix4fv(gl.glGetUniformLocation(shader.id, "model"), 1, gl.GL_TRUE, model.elementPtr());

            gl.glDrawArrays(gl.GL_TRIANGLES, 0, 36);
        }

        gl.glBindVertexArray(0);

        glfw.glfwSwapBuffers(window);
        glfw.glfwPollEvents();
    }
}

fn processInput(window: Window) void {
    if (glfw.glfwGetKey(window, glfw.GLFW_KEY_ESCAPE) == glfw.GLFW_PRESS) {
        glfw.glfwSetWindowShouldClose(window, 1);
    }

    if (glfw.glfwGetKey(window, glfw.GLFW_KEY_W) == glfw.GLFW_PRESS) 
        camera.processMovement(.forward, delta_time);
    if (glfw.glfwGetKey(window, glfw.GLFW_KEY_S) == glfw.GLFW_PRESS) 
        camera.processMovement(.backward, delta_time);

    if (glfw.glfwGetKey(window, glfw.GLFW_KEY_SPACE) == glfw.GLFW_PRESS) 
        camera.processMovement(.up, delta_time);
    if (glfw.glfwGetKey(window, glfw.GLFW_KEY_LEFT_SHIFT) == glfw.GLFW_PRESS) 
        camera.processMovement(.down, delta_time);

    if (glfw.glfwGetKey(window, glfw.GLFW_KEY_A) == glfw.GLFW_PRESS) 
        camera.processMovement(.left, delta_time);
    if (glfw.glfwGetKey(window, glfw.GLFW_KEY_D) == glfw.GLFW_PRESS)
        camera.processMovement(.right, delta_time);
}

fn framebufferSizeCallback(_: Window, w: c_int, h: c_int) callconv(.c) void {
    width = w;
    height = h;
    gl.glViewport(0, 0, width, height);
}

fn srcollCallback(_: Window, _: f64, y_offset: f64) callconv(.c) void {
    camera.processMouseScroll(@floatCast(y_offset));
}

fn cursorPosCallback(_: Window, x_pos_in: f64, y_pos_in: f64) callconv(.c) void {
    const x_pos: f32 = @floatCast(x_pos_in);
    const y_pos: f32 = @floatCast(y_pos_in);

    if (first_mouse) {
        last_mouse_x = x_pos;
        last_mouse_y = y_pos;
        first_mouse = false;
    }

    const x_offset = x_pos - last_mouse_x;
    const y_offset = last_mouse_y - y_pos;

    last_mouse_x = x_pos;
    last_mouse_y = y_pos;

    camera.processMouseMovement(x_offset, y_offset, true);
}
