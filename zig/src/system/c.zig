const c = @cImport({
    @cInclude("GLFW/glfw3.h");
    @cInclude("OpenGL/gl3.h");

    // TODO
    // @cInclude("epoxy/gl.h");
    // @cInclude("GLFW/glfw3.h");
    // @cInclude("stb_image.h");
    // @cInclude("unistd.h");
});

pub usingnamespace c;
