const std = @import("std");

const mem = @import("memory.zig");
const MemoryPtr = mem.MemoryPtr;

const runtime = @import("runtime.zig");
const Cell = runtime.Cell;
const MainMemoryLayout = runtime.MainMemoryLayout;

const register = @import("register.zig");
const Register = register.Register;

const dictionary = @import("dictionary.zig");
const Dictionary = dictionary.Dictionary;

const input_buffer = @import("input_buffer.zig");
const InputBuffer = input_buffer.InputBuffer;

pub const Error = error{
    InvalidCompileState,
};

pub const CompileState = enum(Cell) {
    interpret = 0,
    compile,
    _,
};

pub const Interpreter = struct {
    memory: MemoryPtr,

    dictionary: Dictionary,
    state: Register(MainMemoryLayout.offsetOf("state")),
    base: Register(MainMemoryLayout.offsetOf("base")),
    input_buffer: InputBuffer,

    should_bye: bool,
    should_quit: bool,

    pub fn init(self: *@This(), memory: MemoryPtr) void {
        self.memory = memory;

        self.dictionary.init(self.memory);
        self.state.init(self.memory);
        self.base.init(self.memory);
        self.input_buffer.init(self.memory);

        self.state.store(@intFromEnum(CompileState.interpret));
        self.base.store(10);
    }

    //

    pub fn repl(self: *@This()) Error!void {
        self.should_bye = false;

        while (!self.should_bye) {
            self.should_quit = false;

            var did_refill = try self.input_source.refill();

            while (did_refill and !self.should_quit and !self.should_bye) {
                const word = self.input_source.readNextWord();
                if (word) |w| {
                    try self.evaluateString(w);
                } else {
                    did_refill = try self.input_source.refill();
                }
            }

            try self.onQuit();
        }

        try self.onBye();
    }

    pub fn onQuit(self: *@This()) !void {
        // TODO set refiller to cmd line input
        // TODO remove next line when bye/quit logic is figured out
        self.should_bye = true;
    }

    pub fn onBye(self: *@This()) !void {
        _ = self;
    }

    //

    fn assertValidCompileState(self: @This()) !void {
        const state = @as(CompileState, @enumFromInt(self.state.fetch()));
        switch (state) {
            .interpret, .compile => {},
            else => return error.InvalidCompileState,
        }
    }

    pub fn evaluateString(self: *@This(), word: []const u8) !void {
        const state = @as(CompileState, @enumFromInt(self.state.fetch()));
        try self.assertValidCompileState();

        // TODO this next line is messy
        const wordlist_idx: Cell = if (state == .interpret) 0 else 1;
        _ = word;
        _ = wordlist_idx;
        //         if (try self.lookupString(wordlist_idx, word)) |word_info| {
        //             switch (state) {
        //                 .interpret => {
        //                     try self.interpret(word_info);
        //                 },
        //                 .compile => {
        //                     try self.compile(word_info);
        //                 },
        //                 else => unreachable,
        //             }
        //         } else {
        //             // TODO printWordNotFound fn
        //             std.debug.print("Word not found: {s}\n", .{word});
        //             return error.WordNotFound;
        //         }
    }
};
