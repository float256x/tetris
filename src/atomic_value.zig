const std = @import("std");
const Mutex = std.Thread.Mutex;

pub fn AtomicValue(comptime T: type) type {
    return struct {
        raw: T,
        mutex: Mutex,

        pub fn init(item: T) AtomicValue(T) {
            return AtomicValue(T){
                .raw = item,
                .mutex = Mutex{},
            };
        }

        pub fn get(self: *AtomicValue(T)) T {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.raw;
        }

        pub fn set(self: *AtomicValue(T), item: T) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.raw = item;
        }
    };
}
