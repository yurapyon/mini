const mini = @import("mini");
const kernel = mini.kernel;
const Kernel = kernel.Kernel;
const Cell = kernel.Cell;

// ===

// >t   to thread stack
// t> from thread stack

// docol can log stack pointer at start of function

const SuspensionType = union(enum) {
    yield,
    wait_frames: usize,
    wait_until_next_beat: usize,
};

const Thread = struct {
    // Set on spawn/resume
    data_stack_pointer_at_start: Cell,
    return_stack_pointer_at_start: Cell,

    // Set on suspend
    data_stack: Cell[64],
    data_stack_depth: Cell,
    return_stack: Cell[64],
    return_stack_depth: Cell,
    suspension_type: SuspensionType,

    // do we need pc if we have rstack ??
    program_counter: Cell,
};

const Scheduler = struct {
    kernel: *Kernel,
    // semaphore

    pub fn init(self: *@This(), k: *Kernel) void {
        self.kernel = k;
    }

    pub fn main(self: *@This()) !void {
        while (true) {
            try self.kernel.execute();
            if (self.kernel.exectuion_status == .paused) {
                // TODO handle pause
                // self.semaphore.wait()
            } else {
                // If you get here you know that kernel exited without pausing
                break;
            }
        }
    }
};
