const std = @import("std");
const Mutex = std.Thread.Mutex;
const Array = std.BoundedArray;

pub fn AtomicQueue(comptime T: type, comptime N: usize) type {
    return struct {
        mutex: Mutex,
        array: Array(T, N),

        pub fn init() !@This() {
            return AtomicQueue(T, N){
                .mutex = Mutex{},
                .array = try Array(T, N).init(0),
            };
        }

        pub fn prepend(self: *@This(), item: T) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            if (self.array.len < N) {
                // fail silentily if array is full
                if (self.array.insert(0, item)) {} else |_| {}
            }
        }

        pub fn popOrNull(self: *@This()) ?T {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.array.popOrNull();
        }

        pub fn clear(self: *@This()) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.array.resize(0) catch unreachable;
        }
    };
}

test "use" {
    var queue = try AtomicQueue(u8, 3).init();
    queue.prepend(1);
    queue.prepend(2);
    queue.prepend(3);
    queue.prepend(4);
    const x = queue.popOrNull().?;
    try std.testing.expectEqual(1, x);
}
