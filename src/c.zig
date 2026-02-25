pub const glad = @cImport({
    @cInclude("glad/glad.h");
});

pub const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub const stb_image = @cImport({
    @cInclude("stb_image.h");
});

pub const Window = ?*glfw.GLFWwindow;
