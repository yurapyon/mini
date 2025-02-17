const mem = @import("memory.zig");
const MemoryPtr = mem.MemoryPtr;

const runtime = @import("runtime.zig");
const Cell = runtime.Cell;
const SignedCell = runtime.SignedCell;

const register = @import("register.zig");
const Register = register.Register;

// ===

pub fn Stack(
    comptime top_ptr_addr: Cell,
    comptime stack_bottom: Cell,
    comptime stack_top: Cell,
) type {
    return struct {
        memory: MemoryPtr,
        // NOTE
        // This is guaranteed to be Cell aligned as long as stack_bottom is
        //   This can get messed up from forth though
        top: Register(top_ptr_addr),

        // TODO comptime check that stack_size is 32
        const stack_size = stack_top - stack_bottom;
        const wrap_mask = 0x3f;

        pub fn init(self: *@This(), memory: MemoryPtr) void {
            self.memory = memory;

            self.top.init(self.memory);
            self.top.store(stack_bottom);
        }

        //         fn wrappedIndex(self: *@This(), offset: isize) Cell {
        //             const top = self.top.fetch();
        //             const idx = top - stack_bottom;
        //             const new_idx = idx + offset * @sizeOf(Cell);
        //             const wrapped_idx: Cell = @intCast(@mod(new_idx, stack_size));
        //             return wrapped_idx + stack_bottom;
        //         }

        pub fn peek(self: *@This(), at: isize) *Cell {
            // const idx = self.wrappedIndex(at);
            const idx = self.top.fetch() + stack_bottom + at;
            return mem.cellPtr(self.memory, idx & wrap_mask) catch unreachable;
        }

        pub fn peekSigned(self: *@This(), at: isize) *SignedCell {
            const idx = self.wrappedIndex(at);
            const cell_ptr = mem.cellPtr(self.memory, idx) catch unreachable;
            return @ptrCast(cell_ptr);
        }

        pub fn pop(self: *@This()) void {
            self.top.storeSubtract(@sizeOf(Cell));
            self.top.mask(wrap_mask);
        }

        pub fn push(self: *@This()) void {
            self.top.storeAdd(@sizeOf(Cell));
            self.top.mask(wrap_mask);
        }

        // ===

        pub fn pushCell(self: *@This(), value: Cell) void {
            const next_top = self.peek(1);
            next_top.* = value;
            self.push();
        }

        pub fn pushBoolean(self: *@This(), value: bool) void {
            self.pushCell(runtime.cellFromBoolean(value));
        }

        pub fn popCell(self: *@This()) Cell {
            const top = self.peek(0);
            self.pop();
            return top.*;
        }

        pub fn debugPrint(self: *@This()) void {
            const std = @import("std");
            for (0..(stack_size / @sizeOf(Cell))) |i| {
                const at = -@as(isize, @intCast(i));
                std.debug.print("{x:2}: {}\n", .{ i, self.peek(at).* });
            }
        }

        // ===

        pub fn dup(self: *@This()) void {
            const top = self.peek(0);
            const next_top = self.peek(1);
            next_top.* = top.*;
            self.push();
        }

        pub fn drop(self: *@This()) void {
            self.pop();
        }

        pub fn eq(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(-1);
            self.pushBoolean(top.* == second.*);
        }

        pub fn eq0(self: *@This()) void {
            const top = self.peek(0);
            self.pushBoolean(top.* == 0);
        }

        pub fn gt(self: *@This()) void {
            const top = self.peekSigned(0);
            const second = self.peekSigned(-1);
            self.pop();
            self.pop();
            self.pushBoolean(second.* > top.*);
        }
    };
}
