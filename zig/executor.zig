const vm = @import("mini.zig");
const bytecodes = @import("bytecodes.zig");

pub const Executor = struct {
    memory: []u8,
    program_counter: vm.Cell,
    return_stack: vm.Cell,

    // TODO note
    // can handle stack traces and stuff here

    // TODO
    // 'exit' should call something from in here that will update the stacktrace stack

    pub fn executeMiniWord(self: *@This(), cfa_addr: vm.Cell) vm.Error!void {
        // const cfa_addr = try self.dictionary.toCfa(addr);

        // NOTE
        // this puts some 'dummy data' on the return stack
        // the 'dummy data' is actually the xt currently being executed
        //   and can be accessed with `r0 @` from forth
        // i think its more clear to write it out this way
        //   rather than using the absoluteJump function below
        self.return_stack.push(cfa_addr) catch |err| {
            _ = err;
            // return returnStackErrorFromStackError(err);
        };
        self.program_counter.store(cfa_addr);
        try self.executionLoop();
    }

    fn executionLoop(self: *@This()) vm.Error!void {
        // Execution strategy:
        //   1. increment PC, then
        //   2. evaluate byte at PC-1
        // this makes return stack and jump logic easier
        //   because bytecodes can just set the jump location
        //     directly without having to do any math

        while (self.return_stack.depth() > 0) {
            const bytecode = try self.readByteAndAdvancePC();
            const ctx = vm.ExecutionContext{
                .current_bytecode = bytecode,
            };
            try bytecodes.getBytecodeDefinition(bytecode).executeSemantics(
                self,
                ctx,
            );
        }
    }

    pub fn absoluteJump(
        self: *@This(),
        addr: vm.Cell,
        useReturnStack: bool,
    ) vm.Error!void {
        if (useReturnStack) {
            self.return_stack.push(self.program_counter.fetch()) catch |err| {
                _ = err;
                // return returnStackErrorFromStackError(err);
            };
        }
        self.program_counter.store(addr);
    }

    pub fn readByteAndAdvancePC(self: *@This()) vm.mem.MemoryError!u8 {
        return try self.program_counter.readByteAndAdvance(self.memory);
    }

    pub fn readCellAndAdvancePC(self: *@This()) vm.mem.MemoryError!vm.Cell {
        return try self.program_counter.readCellAndAdvance(self.memory);
    }
};
