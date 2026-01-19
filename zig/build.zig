const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod_mini = b.addModule("mini", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const mod_pyon = b.addModule("pyon", .{
        .root_source_file = b.path("src/system/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "mini", .module = mod_mini },
        },
    });

    switch (target.result.os.tag) {
        .macos => {
            mod_mini.linkSystemLibrary("c", .{});

            mod_pyon.linkSystemLibrary("c", .{});
            mod_pyon.linkSystemLibrary("glfw3", .{});
            mod_pyon.linkFramework("OpenGL", .{});
            mod_pyon.linkFramework("Cocoa", .{});
            mod_pyon.linkFramework("IOKit", .{});
            mod_pyon.linkFramework("CoreVideo", .{});
        },
        else => {},
    }

    mod_pyon.addIncludePath(b.path("src/system/deps"));
    mod_pyon.addCSourceFile(.{
        .file = b.path("src/system/deps/stb_image.c"),
        .flags = &[_][]const u8{"-std=c99"},
    });

    const exe = b.addExecutable(.{
        .name = "mini",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "mini", .module = mod_mini },
                .{ .name = "pyon", .module = mod_pyon },
            },
        }),
    });

    // ===

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    // const lib_unit_tests = b.addTest(.{
    // .root_source_file = b.path("src/root.zig"),
    // .target = target,
    // .optimize = optimize,
    // });

    // Creates an executable that will run `test` blocks from the provided module.
    // Here `mod` needs to define a target, which is why earlier we made sure to
    // set the releative field.
    const mod_tests = b.addTest(.{
        .root_module = mod_mini,
    });

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);

    // Creates an executable that will run `test` blocks from the executable's
    // root module. Note that test executables only test one module at a time,
    // hence why we have to create two separate ones.
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    // A run step that will run the second test executable.
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
