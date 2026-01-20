const std = @import("std");

fn setupWasm(b: *std.Build, mod_mini: *std.Build.Module) *std.Build.Step {
    // references
    // https://github.com/CornSnek/wasm-shared-memory-zig
    // https://github.com/daneelsan/minimal-zig-wasm-canvas

    const target_wasm = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
        .cpu_features_add = std.Target.wasm.featureSet(&.{ .atomics, .bulk_memory }),
    });

    const wasm = b.addExecutable(.{
        .name = "mini-wasm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm/main.zig"),
            .target = target_wasm,
            .optimize = .ReleaseSmall,
            .imports = &.{
                .{ .name = "mini", .module = mod_mini },
            },
        }),
    });

    wasm.entry = .disabled;
    wasm.rdynamic = true;

    // const wasm_memory_page_count = 4;

    // <https://github.com/ziglang/zig/issues/8633>
    // wasm.global_base = 6560;
    wasm.import_memory = true;
    // wasm.shared_memory = true;
    // wasm.stack_size = std.wasm.page_size;
    // wasm.initial_memory = std.wasm.page_size * wasm_memory_page_count;
    // wasm.max_memory = std.wasm.page_size * wasm_memory_page_count;

    const wasm_install = b.addInstallArtifact(wasm, .{});

    // TODO
    // copy the docs to /web

    const web_public = "web/public/mini/";

    const copy_wasm = b.addSystemCommand(&.{"cp"});
    copy_wasm.addArg("zig-out/bin/mini-wasm.wasm");
    copy_wasm.addArg(web_public);
    copy_wasm.step.dependOn(&wasm_install.step);

    const copy_precompiled = b.addSystemCommand(&.{"cp"});
    copy_precompiled.addArg("mini-out/precompiled.mini.bin");
    copy_precompiled.addArg(web_public);
    copy_precompiled.step.dependOn(&copy_wasm.step);

    const copy_startup = b.addSystemCommand(&.{"cp"});
    copy_startup.addArg("src/startup.mini.fth");
    copy_startup.addArg(web_public);
    copy_startup.step.dependOn(&copy_precompiled.step);

    // TODO
    // const copy_specs = b.addSystemCommand(&.{"cp"});
    // copy_specs.addArg("specs");
    // copy_specs.addArg(web_public);
    // copy_specs.step.dependOn(&copy_precompiled.step);

    return &copy_startup.step;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod_mini = b.addModule("mini", .{
        .root_source_file = b.path("src/lib/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const mod_libs = b.addModule("libs", .{
        .root_source_file = b.path("src/externals/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "mini", .module = mod_mini },
        },
    });

    const mod_pyon = b.addModule("pyon", .{
        .root_source_file = b.path("src/system/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "mini", .module = mod_mini },
            .{ .name = "libs", .module = mod_libs },
        },
    });

    switch (target.result.os.tag) {
        .macos => {
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

    const desktop = b.addExecutable(.{
        .name = "mini",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "mini", .module = mod_mini },
                .{ .name = "libs", .module = mod_libs },
                .{ .name = "pyon", .module = mod_pyon },
            },
        }),
    });

    const desktop_install = b.addInstallArtifact(desktop, .{});

    const desktop_step = b.step("desktop", "Build and install desktop");
    desktop_step.dependOn(&desktop.step);

    const run_cmd = b.addRunArtifact(desktop);
    run_cmd.step.dependOn(&desktop_install.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // ===

    const wasm = setupWasm(b, mod_mini);

    const wasm_step = b.step("wasm", "Build and install wasm");
    wasm_step.dependOn(wasm);

    // ===

    b.getInstallStep().dependOn(&desktop_install.step);
    b.getInstallStep().dependOn(wasm);

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
    // TODO
    // const mod_tests = b.addTest(.{
    // .root_module = mod_mini,
    // });

    // A run step that will run the test executable.
    // const run_mod_tests = b.addRunArtifact(mod_tests);

    // Creates an executable that will run `test` blocks from the executable's
    // root module. Note that test executables only test one module at a time,
    // hence why we have to create two separate ones.
    // const exe_tests = b.addTest(.{
    // .root_module = exe.root_module,
    // });

    // A run step that will run the second test executable.
    // const run_exe_tests = b.addRunArtifact(exe_tests);

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    // const test_step = b.step("test", "Run tests");
    // test_step.dependOn(&run_mod_tests.step);
    // test_step.dependOn(&run_exe_tests.step);
}
