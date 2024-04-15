const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const AtomicQueue = @import("atomic_queue.zig").AtomicQueue;
const AtomicValue = @import("atomic_value.zig").AtomicValue;
pub const Game = @This();

// GLOBAL CONSTANTS
pub const rows = 20 + 4;
pub const cols = 10;
pub const hidden_rows = 4;

pub const block_patterns = [_][]const u8{
    "0000000011110000", // I
    "0000100011100000", // J
    "0000000101110000", // L
    "0000110001100000", // Z
    "0000001101100000", // S
    "0000010011100000", // T
    "0000011001100000", // O
};

const State = struct {
    alive: bool,
    matrix: [rows * cols]u16,
    active_block: u16,
    next_block: u16,
    score: u16,

    pub fn getBlock(self: *const State, row: usize, col: usize) u16 {
        return self.matrix[index(row, col)];
    }
};

pub const Command = enum {
    Left,
    Right,
    Rotate,
    Down,
    Drop,
};

random_gen: std.rand.DefaultPrng,
state: AtomicValue(State),
command_queue: AtomicQueue(Command, 3),
last_step_milli_timestamp: i64,

pub fn init() !Game {
    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    var rg = std.rand.DefaultPrng.init(seed);

    const active_block = rg.random().intRangeAtMost(u8, 1, 8);
    const init_matrix = spawnNewBlock([_]u16{0} ** (rows * cols), active_block) orelse unreachable;
    const next_block = active_block + rg.random().intRangeAtMost(u8, 1, 8);

    const state = State{
        .alive = true,
        .matrix = init_matrix,
        .active_block = active_block,
        .next_block = next_block,
        .score = 0,
    };

    return Game{
        .random_gen = rg,
        .state = AtomicValue(State).init(state),
        .command_queue = try AtomicQueue(Command, 3).init(),
        .last_step_milli_timestamp = 0,
    };
}

pub fn tick(self: *Game) bool {
    const state = self.state.get();
    if (!state.alive) {
        return false;
    }
    // TODO speed up over time
    const step_interval_ms = 300;
    const now = std.time.milliTimestamp();
    if (now - self.last_step_milli_timestamp > step_interval_ms) {
        self.last_step_milli_timestamp = now;
        const new_state = step(state, &self.random_gen);
        self.state.set(new_state);
        //self.printState(); // TODO move?
        if (state.active_block != new_state.active_block) {
            self.command_queue.clear();
        }
        return new_state.alive;
    }
    if (self.command_queue.popOrNull()) |command| {
        const new_state = handleCommand(state, command);
        self.state.set(new_state);
        return true;
    }
    return true;
}

pub fn sendCommand(self: *Game, c: Command) void {
    self.command_queue.prepend(c);
}

fn printState(self: *Game) void {
    const state = self.state.get();
    print("\n", .{});
    for (0..rows) |i| {
        if (i == hidden_rows) {
            print("|{s}|\n", .{"--" ** cols});
        }
        print("|", .{});
        for (0..cols) |j| {
            print("{} ", .{state.matrix[i * cols + j]});
        }
        print("|\n", .{});
    }
}

fn handleCommand(state: State, command: Command) State {
    if (!state.alive) {
        return state;
    }
    if (command == .Down) {
        if (tryBlockDown(state)) |new_state| {
            return new_state;
        } else {
            return state;
        }
    }
    if (command == .Drop) {
        var new_state = state;
        return while (tryBlockDown(new_state)) |s| {
            new_state = s;
        } else new_state;
    }
    if (command == .Left) {
        if (tryBlockLeft(state)) |new_state| {
            return new_state;
        } else {
            return state;
        }
    }
    if (command == .Right) {
        if (tryBlockRight(state)) |new_state| {
            return new_state;
        } else {
            return state;
        }
    }
    if (command == .Rotate) {
        return blockRotate(state);
    }
    unreachable;
}

fn createNewBlock(block: u16) [hidden_rows * cols]u16 {
    var area = [_]u16{0} ** (hidden_rows * cols);
    const center_col = cols / 2;
    const block_pattern = block_patterns[block % 7];
    for (0..16) |i| {
        const row = i / 4;
        const col = center_col - 2 + (i % 4);
        if (block_pattern[i] == '1') {
            area[index(row, col)] = block;
        }
    }
    return area;
}

fn index(row: usize, col: usize) usize {
    assert(row < rows);
    assert(col < cols);
    return row * cols + col;
}

fn tryBlockDown(state: State) ?State {
    return tryMoveBlock(state, false, false, true);
}

fn tryBlockLeft(state: State) ?State {
    return tryMoveBlock(state, true, false, false);
}

fn tryBlockRight(state: State) ?State {
    return tryMoveBlock(state, false, true, false);
}

fn tryMoveBlock(state: State, left: bool, right: bool, down: bool) ?State {
    var new_matrix: [cols * rows]u16 = undefined;
    std.mem.copyForwards(u16, &new_matrix, &state.matrix);
    for (1..rows + 1) |i| {
        const row = rows - i;
        for (0..cols) |col| {
            const cell_block = state.matrix[index(row, col)];
            if (cell_block != state.active_block) {
                continue;
            }
            var new_col = col;
            var new_row = row;
            if (left) {
                if (col == 0) {
                    return null;
                }
                new_col -= 1;
            }
            if (right) {
                new_col += 1;
            }
            if (down) {
                new_row += 1;
            }
            if (new_col >= cols or new_row >= rows) {
                return null;
            }
            new_matrix[index(row, col)] -= state.active_block;
            new_matrix[index(new_row, new_col)] += state.active_block;
        }
    }
    if (anyBlocksOverlap(new_matrix, state.active_block)) {
        return null;
    }
    return State{
        .alive = state.alive,
        .matrix = new_matrix,
        .active_block = state.active_block,
        .next_block = state.next_block,
        .score = state.score,
    };
}

fn blockRotate(state: State) State {
    var max_row: usize = 0;
    var min_row: usize = rows;
    var min_col: usize = cols;
    var max_col: usize = 0;
    for (0..rows) |row| {
        for (0..cols) |col| {
            if (state.matrix[index(row, col)] == state.active_block) {
                min_row = @min(min_row, row);
                max_row = @max(max_row, row);
                min_col = @min(min_col, col);
                max_col = @max(max_col, col);
            }
        }
    }
    const width = max_col - min_col;
    const height = max_row - min_row;
    const new_width = height;
    const new_height = width;
    var new_matrix: [cols * rows]u16 = undefined;
    std.mem.copyForwards(u16, &new_matrix, &state.matrix);
    // Transpose
    const new_min_row = @max(max_row, new_height) - new_height;
    const new_min_col = @max(max_col, new_width) - new_width;
    for (new_min_row..new_min_row + new_height + 1) |new_row| {
        for (new_min_col..new_min_col + new_width + 1) |new_col| {
            const row = max_row - (new_col - new_min_col);
            const col = min_col + (new_row - new_min_row);
            if (state.matrix[index(row, col)] == state.active_block) {
                new_matrix[index(new_row, new_col)] += state.active_block;
            }
        }
    }
    for (0..index(rows - 1, cols - 1) + 1) |idx| {
        if (state.matrix[idx] == state.active_block) {
            new_matrix[idx] -= state.active_block;
        }
    }
    return State{
        .alive = state.alive,
        .matrix = new_matrix,
        .active_block = state.active_block,
        .next_block = state.next_block,
        .score = state.score,
    };
}

fn anyBlocksOverlap(matrix: [rows * cols]u16, active_block: u16) bool {
    for (0..index(rows - 1, cols - 1) + 1) |idx| {
        std.debug.assert(matrix[idx] >= 0);
        if (matrix[idx] > active_block) {
            return true;
        }
    }
    return false;
}

fn applyGravity(matrix: [rows * cols]u16, empty_row: usize) [rows * cols]u16 {
    for (0..cols) |col| {
        assert(matrix[index(empty_row, col)] == 0);
    }
    var new_matrix: [cols * rows]u16 = undefined;
    std.mem.copyForwards(u16, &new_matrix, &matrix);
    for (1..empty_row + 1) |i| {
        const row = empty_row - i;
        for (0..cols) |col| {
            const new_row = row + 1;
            new_matrix[index(new_row, col)] = new_matrix[index(row, col)];
            new_matrix[index(row, col)] = 0;
        }
    }
    return new_matrix;
}

fn terminateRound(state: State, random_gen: *std.rand.DefaultPrng) ?State {
    var new_matrix: [cols * rows]u16 = undefined;
    std.mem.copyForwards(u16, &new_matrix, &state.matrix);
    var count_rows_cleared: u8 = 0;
    row_loop: for (1..rows + 1) |i| {
        const row = rows - i;
        while (true) {
            for (0..cols) |col| {
                if (new_matrix[index(row, col)] == 0) {
                    // row is not complete
                    continue :row_loop;
                }
            }
            // row is complete
            count_rows_cleared += 1;
            // clear current line
            for (0..cols) |col| {
                new_matrix[index(row, col)] = 0;
            }
            new_matrix = applyGravity(new_matrix, row);
        }
    }
    const new_score = state.score + 10 * (count_rows_cleared * count_rows_cleared);
    // Spawn new block
    const new_active_block = state.next_block;
    if (spawnNewBlock(new_matrix, new_active_block)) |mat| {
        const new_next_block = new_active_block + random_gen.random().intRangeAtMost(u16, 1, 8);
        return State{
            .alive = state.alive,
            .matrix = mat,
            .active_block = new_active_block,
            .next_block = new_next_block,
            .score = new_score,
        };
    }
    return null;
}

fn spawnNewBlock(matrix: [rows * cols]u16, new_block: u16) ?[rows * cols]u16 {
    var new_matrix: [rows * cols]u16 = undefined;
    std.mem.copyForwards(u16, &new_matrix, &matrix);
    const hidden_area = createNewBlock(new_block);
    for (0..(hidden_rows * cols)) |idx| {
        if (new_matrix[idx] != 0) {
            // DEATH
            return null;
        }
        new_matrix[idx] = hidden_area[idx];
    }
    return new_matrix;
}

fn step(state: State, random_gen: *std.rand.DefaultPrng) State {
    if (anyBlocksOverlap(state.matrix, state.active_block)) {
        return State{
            .alive = false,
            .matrix = state.matrix,
            .active_block = state.active_block,
            .next_block = state.next_block,
            .score = state.score,
        };
    }
    if (tryBlockDown(state)) |new_state| {
        return new_state;
    }
    if (terminateRound(state, random_gen)) |new_state| {
        return new_state;
    }
    return State{
        .alive = false,
        .matrix = state.matrix,
        .active_block = state.active_block,
        .next_block = state.next_block,
        .score = state.score,
    };
}
