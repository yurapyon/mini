const mem = @import("memory.zig");
const MemoryPtr = mem.MemoryPtr;

const kernel = @import("kernel.zig");
const Cell = kernel.Cell;
const SignedCell = kernel.SignedCell;

const register = @import("register.zig");
const Register = register.Register;

// ===

pub fn Stack(
    comptime top_ptr_addr: Cell,
    comptime top_addr: Cell,
) type {
    return struct {
        memory: MemoryPtr,
        // NOTE
        // This is guaranteed to be Cell aligned as long
        //     as top_addr is
        //   This can get messed up from forth though
        top_ptr: Register(top_ptr_addr),

        pub fn init(self: *@This(), memory: MemoryPtr) void {
            self.memory = memory;
            self.top_ptr.init(self.memory);
            self.top_ptr.store(top_addr);
        }

        pub fn initTopPtr(self: *@This()) void {
            self.top_ptr.store(top_addr);
        }

        pub fn depth(self: @This()) Cell {
            const current_top = self.top_ptr.fetch();
            return top_addr - current_top;
        }

        fn peek(self: *@This(), at: Cell) *Cell {
            // TODO handle stack underflow
            const addr = self.top_ptr.fetch() + at * @sizeOf(Cell);
            // @import("std").debug.print("addr {} {}\n", .{ addr, top_addr });
            if (addr >= top_addr) unreachable;
            return mem.cellPtr(self.memory, addr) catch unreachable;
        }

        fn peekSigned(self: *@This(), at: Cell) *SignedCell {
            const cell_ptr = self.peek(at);
            return @ptrCast(cell_ptr);
        }

        fn pop(self: *@This(), count: Cell) void {
            self.top_ptr.storeAdd(count * @sizeOf(Cell));
        }

        fn push(self: *@This(), count: Cell) void {
            self.top_ptr.storeSubtract(count * @sizeOf(Cell));
        }

        fn constPeek(self: @This(), at: Cell) Cell {
            // TODO handle stack underflow
            const addr = self.top_ptr.fetch() + at * @sizeOf(Cell);
            // @import("std").debug.print("addr {} {}\n", .{ addr, top_addr });
            if (addr >= top_addr) unreachable;
            return mem.readCell(self.memory, addr) catch unreachable;
        }

        // ===

        pub fn pushCell(self: *@This(), value: Cell) void {
            self.push(1);
            const top = self.peek(0);
            top.* = value;
        }

        pub fn pushBoolean(self: *@This(), value: bool) void {
            self.pushCell(kernel.cellFromBoolean(value));
        }

        pub fn popCell(self: *@This()) Cell {
            const top = self.peek(0);
            self.pop(1);
            return top.*;
        }

        pub fn peekCell(self: *@This()) Cell {
            return self.peek(0).*;
        }

        pub fn debugPrint(self: @This()) void {
            const std = @import("std");
            for (0..(self.depth() / @sizeOf(Cell))) |i| {
                const at = @as(Cell, @intCast(i));
                std.debug.print("{x:2}: {}\n", .{ i, self.constPeek(at) });
            }
        }

        pub fn popSignedCell(self: *@This()) SignedCell {
            const top = self.peekSigned(0);
            self.pop(1);
            return top.*;
        }

        pub fn pushSignedCell(self: *@This(), value: SignedCell) void {
            self.push(1);
            const top = self.peekSigned(0);
            top.* = value;
        }

        // stack manip ===

        pub fn dup(self: *@This()) void {
            self.push(1);
            const top = self.peek(0);
            const second = self.peek(1);
            top.* = second.*;
        }

        pub fn drop(self: *@This()) void {
            self.pop(1);
        }

        pub fn swap(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(1);
            const temp = top.*;
            top.* = second.*;
            second.* = temp;
        }

        pub fn flip(self: *@This()) void {
            const top = self.peek(0);
            const third = self.peek(2);
            const temp = top.*;
            top.* = third.*;
            third.* = temp;
        }

        pub fn over(self: *@This()) void {
            self.push(1);
            const top = self.peek(0);
            const third = self.peek(2);
            top.* = third.*;
        }

        pub fn nip(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(1);
            second.* = top.*;
            self.pop(1);
        }

        pub fn tuck(self: *@This()) void {
            self.push(1);
            const top = self.peek(0);
            const second = self.peek(1);
            const third = self.peek(2);

            top.* = second.*;
            second.* = third.*;
            third.* = top.*;
        }

        pub fn rot(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(1);
            const third = self.peek(2);

            const temp = top.*;

            top.* = third.*;
            third.* = second.*;
            second.* = temp;
        }

        pub fn nrot(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(1);
            const third = self.peek(2);

            const temp = top.*;

            top.* = second.*;
            second.* = third.*;
            third.* = temp;
        }

        // logic ===

        pub fn eq(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(1);
            second.* = kernel.cellFromBoolean(top.* == second.*);
            self.pop(1);
        }

        pub fn eq0(self: *@This()) void {
            const top = self.peek(0);
            top.* = kernel.cellFromBoolean(top.* == 0);
        }

        pub fn gt(self: *@This()) void {
            const top = self.peekSigned(0);
            const ssecond = self.peekSigned(1);
            const second = self.peek(1);
            second.* = kernel.cellFromBoolean(ssecond.* > top.*);
            self.pop(1);
        }

        pub fn gteq(self: *@This()) void {
            const top = self.peekSigned(0);
            const ssecond = self.peekSigned(1);
            const second = self.peek(1);
            second.* = kernel.cellFromBoolean(ssecond.* >= top.*);
            self.pop(1);
        }

        pub fn lt(self: *@This()) void {
            const top = self.peekSigned(0);
            const ssecond = self.peekSigned(1);
            const second = self.peek(1);
            second.* = kernel.cellFromBoolean(ssecond.* < top.*);
            self.pop(1);
        }

        pub fn lteq(self: *@This()) void {
            const top = self.peekSigned(0);
            const ssecond = self.peekSigned(1);
            const second = self.peek(1);
            second.* = kernel.cellFromBoolean(ssecond.* <= top.*);
            self.pop(1);
        }

        pub fn ugt(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(1);
            second.* = kernel.cellFromBoolean(second.* > top.*);
            self.pop(1);
        }

        pub fn ugteq(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(1);
            second.* = kernel.cellFromBoolean(second.* >= top.*);
            self.pop(1);
        }

        pub fn ult(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(1);
            second.* = kernel.cellFromBoolean(second.* < top.*);
            self.pop(1);
        }

        pub fn ulteq(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(1);
            second.* = kernel.cellFromBoolean(second.* <= top.*);
            self.pop(1);
        }

        // bits ===

        pub fn and_(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(1);
            second.* &= top.*;
            self.pop(1);
        }

        pub fn ior(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(1);
            second.* |= top.*;
            self.pop(1);
        }

        pub fn xor(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(1);
            second.* ^= top.*;
            self.pop(1);
        }

        pub fn invert(self: *@This()) void {
            const top = self.peek(0);
            top.* = ~top.*;
        }

        pub fn lshift(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(1);
            second.* <<= @truncate(top.*);
            self.pop(1);
        }

        pub fn rshift(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(1);
            second.* >>= @truncate(top.*);
            self.pop(1);
        }

        // math ===

        pub fn inc(self: *@This()) void {
            const top = self.peek(0);
            top.* +%= 1;
        }

        pub fn dec(self: *@This()) void {
            const top = self.peek(0);
            top.* -%= 1;
        }

        pub fn add(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(1);
            second.* +%= top.*;
            self.pop(1);
        }

        pub fn subtract(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(1);
            second.* -%= top.*;
            self.pop(1);
        }

        pub fn multiply(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(1);
            second.* *%= top.*;
            self.pop(1);
        }

        // TODO these should be signed
        pub fn divide(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(1);
            if (top.* != 0) {
                second.* /= top.*;
            } else {
                second.* = 0;
            }
            self.pop(1);
        }

        // TODO these should be signed
        pub fn mod(self: *@This()) void {
            const top = self.peek(0);
            const second = self.peek(1);
            if (top.* != 0) {
                second.* %= top.*;
            } else {
                second.* = 0;
            }
            self.pop(1);
        }
    };
}
