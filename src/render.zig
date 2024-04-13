const std = @import("std");
const tetris = @import("tetris.zig");
const Game = tetris.Game;

const colored_cells = [_][]const u8{
    "<div class='color0 cell'></div>",
    "<div class='color1 cell'></div>",
    "<div class='color2 cell'></div>",
    "<div class='color3 cell'></div>",
    "<div class='color4 cell'></div>",
    "<div class='color5 cell'></div>",
    "<div class='color6 cell'></div>",
};

const block_preview = [_][]const u8{
    "0000000011110000", // I
    "0000100011100000", // J
    "0000000101110000", // L
    "0000110001100000", // Z
    "0000001101100000", // S
    "0000010011100000", // T
    "0000011001100000", // O
};

pub fn renderGame(g: ?*Game, out: *std.BoundedArray(u8, 10000)) !void {
    if (g) |game| {
        const state = game.state.get();

        try out.appendSlice("<div class='row'>");
        try out.appendSlice("<div class='column70'>");
        if (!state.alive) {
            try out.appendSlice("<div class='gameover'>⚔ GAME OVER ⚔</div>");
        }
        for (tetris.hidden_rows..tetris.rows) |row| {
            try out.appendSlice("<div>");
            for (0..tetris.cols) |col| {
                const block = state.getBlock(row, col);
                if (block == 0) {
                    try out.appendSlice("<div class='empty cell'></div>");
                } else {
                    const colored_cell = colored_cells[block % colored_cells.len];
                    try out.appendSlice(colored_cell);
                }
            }
            try out.appendSlice("</div>");
        }
        try out.appendSlice("</div>"); // end column
        try out.appendSlice("<div class='column30'><div id='score'>🟊");

        var buf: [10]u8 = undefined;
        const score_string = try std.fmt.bufPrint(&buf, "{}", .{state.score});
        try out.appendSlice(score_string);

        try out.appendSlice("</div><div id='block_preview'>");
        const pattern = block_preview[state.next_block % 7];
        try out.appendSlice("<div>");
        for (0..16) |j| {
            if (pattern[j] == '1') {
                try out.appendSlice(colored_cells[state.next_block % 7]);
            } else {
                try out.appendSlice("<div class='hidden cell'></div>");
            }
            if ((j + 1) % 4 == 0) {
                try out.appendSlice("</div>"); // new row
                try out.appendSlice("<div>");
            }
        }
        try out.appendSlice("</div>");
        // try out.appendSlice(@tagName(state.board.next_block_type));
        try out.appendSlice("</div></div>"); // end column
        try out.appendSlice("</div>"); // end row
    } else {
        try out.appendSlice("");
    }
}
