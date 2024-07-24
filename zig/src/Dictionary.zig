const vm = @import("MiniVM.zig");

const bytecodes = @import("bytecodes.zig");
const WordHeader = @import("WordHeader.zig").WordHeader;
const Register = @import("Register.zig").Register;

pub const Dictionary = struct {
    // TODO i think this should be a pointer ?
    memory: vm.Memory,
    latest: Register,
    here: Register,

    // Note
    // assumes latest and here are in the same memory block as the dictionary
    pub fn init(
        self: *@This(),
        memory: vm.Memory,
        latest_offset: vm.Cell,
        here_offset: vm.Cell,
    ) void {
        self.memory = memory;
        self.latest.init(memory, latest_offset);
        self.here.init(memory, here_offset);
    }

    pub fn lookup(
        self: *@This(),
        word: []const u8,
    ) vm.Error!?vm.Cell {
        var latest = self.latest.fetch();
        var temp_word_header: WordHeader = undefined;
        while (latest != 0) : (latest = temp_word_header.latest) {
            try temp_word_header.initFromMemory(self.memory[latest..]);
            if (!temp_word_header.is_hidden and temp_word_header.nameEquals(word)) {
                return latest;
            }
        }
        return null;
    }

    pub fn defineWordHeader(
        self: *@This(),
        name: []const u8,
    ) vm.Error!void {
        const word_header = WordHeader{
            .latest = self.latest.fetch(),
            .is_immediate = false,
            .is_hidden = false,
            .name = name,
        };
        const header_size = @as(vm.Cell, @truncate(word_header.size()));
        self.here.alignForward(vm.Cell);
        const aligned_here = self.here.fetch();
        self.latest.store(aligned_here);
        try word_header.writeToMemory(
            self.memory[aligned_here..][0..header_size],
        );
        self.here.storeAdd(header_size);
        self.here.alignForward(vm.Cell);
    }

    pub fn compile(self: *@This(), word_info: vm.WordInfo) void {
        switch (word_info.value) {
            .bytecode => |bytecode| {
                switch (bytecodes.determineType(bytecode)) {
                    .basic => {
                        self.here.commaC(bytecode);
                    },
                    .data, .absolute_jump => {
                        // TODO error
                        // this is a case that shouldnt happen in normal execution
                        // but may happen if compile was called not from the main executor
                    },
                }
            },
            .mini_word => |addr| {
                _ = addr;
                // TODO
                // compile an abs jump to the cfa of this addr
            },
            .number => |value| {
                if ((value & 0xff00) > 0) {
                    self.here.comma(bytecodes.lookupBytecodeByName("lit") orelse unreachable);
                    self.here.comma(value);
                } else {
                    self.here.comma(bytecodes.lookupBytecodeByName("litc") orelse unreachable);
                    self.here.commaC(@truncate(value));
                }
            },
        }
    }
};

test "dictionary" {
    // TODO
}
