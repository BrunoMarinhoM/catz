const std = @import("std");
const File = std.fs.File;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const child_allocator = gpa.allocator();
var arena_allocator = std.heap.ArenaAllocator.init(child_allocator);
const local_allocator = arena_allocator.allocator();
const print = std.debug.print;
const cwd = std.fs.cwd();

pub fn main() !void {
    try cat();
    std.debug.assert(gpa.deinit() == .ok);
}

pub fn cat() !void {
    var options = std.ArrayList([]u8).init(local_allocator);
    var files_content = std.ArrayList([]u8).init(local_allocator);
    var output_lines = std.ArrayList([]u8).init(local_allocator);
    defer {
        options.deinit();
        output_lines.deinit();
        files_content.deinit();
        arena_allocator.deinit();
    }

    var args = std.process.args();
    const stdout = std.io.getStdOut();

    //skips the calling (cat)
    _ = args.skip();

    outter: while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "-")) {
            for (options.items) |current_item| {
                if (std.mem.eql(u8, arg, current_item)) {
                    continue :outter;
                }
            }
            try options.append(@ptrCast(@constCast(arg)));
        } else {
            const file_path = arg;

            var file = cwd.openFile(file_path, .{ .mode = .read_only }) catch {
                _ = try stdout.write("Error while opening the file\n");
                return;
            };

            const meta = file.metadata() catch {
                _ = try stdout.write("Error while reading the file metadata\n");
                return;
            };

            const file_buffer = try local_allocator.alloc(u8, meta.size());

            _ = file.read(file_buffer) catch {
                _ = try stdout.write("Error while reading the file\n");
                return;
            };

            try files_content.append(file_buffer);
        }
    }

    if (options.items.len == 0) {
        for (files_content.items) |file_buffer| {
            _ = try stdout.write(file_buffer);
            continue;
        }
        return;
    }

    for (files_content.items) |file_buffer| {
        var itt = std.mem.split(u8, file_buffer, "\n");
        while (itt.next()) |line| {
            try output_lines.append(@ptrCast(@constCast(line)));
        }

        for (options.items) |f_arg| {
            if (std.mem.eql(u8, f_arg, "-b") or std.mem.eql(u8, f_arg, "--numbers")) {
                var counter: u16 = 1;

                for (0.., output_lines.items) |outer_index, line| {
                    if (std.mem.eql(u8, line, "")) {
                        continue;
                    }

                    const num_str = try std.fmt.allocPrint(
                        local_allocator,
                        "{d}",
                        .{counter},
                    );

                    const left_pad = try local_allocator.alloc(u8, 6 - num_str.len);

                    for (0..left_pad.len) |index| {
                        left_pad[index] = " ".*[0];
                    }

                    const new_str = try std.fmt.allocPrint(
                        local_allocator,
                        "{s}{s}  {s}",
                        .{ left_pad, num_str, line },
                    );
                    output_lines.items[outer_index] = new_str;
                    counter += 1;
                }
            } else if (std.mem.eql(u8, f_arg, "-n") or std.mem.eql(u8, f_arg, "--numbers")) {
                var counter: u16 = 1;

                for (0.., output_lines.items) |outer_index, line| {
                    const num_str = try std.fmt.allocPrint(
                        local_allocator,
                        "{d}",
                        .{counter},
                    );

                    const left_pad = try local_allocator.alloc(u8, 6 - num_str.len);

                    for (0..left_pad.len) |index| {
                        left_pad[index] = " ".*[0];
                    }

                    const new_str = try std.fmt.allocPrint(
                        local_allocator,
                        "{s}{s}  {s}",
                        .{ left_pad, num_str, line },
                    );

                    output_lines.items[outer_index] = new_str;
                    counter += 1;
                }
            }

            if (std.mem.eql(u8, f_arg, "-E") or std.mem.eql(u8, f_arg, "--show-ends")) {
                for (0.., output_lines.items) |outer_index, line| {
                    const new_str = try std.fmt.allocPrint(
                        local_allocator,
                        "{s}{s}",
                        .{ line, "$" },
                    );
                    output_lines.items[outer_index] = new_str;
                }
            }
        }
    }

    for (output_lines.items) |line| {
        _ = try stdout.write(line);
        _ = try stdout.write("\n");
    }
}
