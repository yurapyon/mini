pub const Timer = struct {
    last_time: f64,
    remainder: f64,
    limit: f64,

    pub fn init(self: *@This()) void {
        self.last_time = 0;
        self.remainder = 0;
        self.limit = 0;
    }

    pub fn update(self: *@This(), now: f64) usize {
        var elapsed = now - self.last_time + self.remainder;

        var ct: usize = 0;
        while (elapsed > self.limit) {
            elapsed -= self.limit;
            ct += 1;
        }

        self.last_time = now;
        self.remainder = elapsed;

        return ct;
    }
};
