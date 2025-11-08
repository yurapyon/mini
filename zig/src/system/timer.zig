pub const Timer = struct {
    accumulator: f64,
    max: f64,

    pub fn accumulate(self: *@This(), time: f64) usize {
        self.accumulator += time;

        var ct: usize = 0;
        while (self.accumulator > self.max) {
            self.accumulator -= self.max;
            ct += 1;
        }

        return ct;
    }
};
