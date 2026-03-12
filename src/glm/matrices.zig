const std = @import("std");
const math = std.math;
const glm = @import("../glm");

fn pow2(x: f32) f32 {
    return math.pow(f32, x, 2);
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualDeep = std.testing.expectEqualDeep;

pub fn assert(ok: bool, comptime err_msg: []const u8) void {
    if (!ok) @compileError(err_msg);
}

pub const Operation = enum {
    add,
    addWrapping,
    addSaturating,
    sub,
    subWrapping,
    subSaturating,
    mul,
    mulWrapping,
    mulSaturating,
    div,
};

pub const Rotation = struct {
    x: f16 = 0,
    y: f16 = 0,
    z: f16 = 0,

    const Self = @This();

    pub fn copy(other: *const Self) Self {
        return .{
            .x = other.x,
            .y = other.y,
            .z = other.z,
        };
    }

    pub fn normalize(self: *Self) void {
        const magnitude: f16 = @floatCast(@sqrt(pow2(self.x) + pow2(self.y) + pow2(self.z)));

        if (math.approxEqRel(f32, magnitude, 1.0, @sqrt(math.floatEps(f32)))) return;

        self.x /= magnitude;
        self.y /= magnitude;
        self.z /= magnitude;
    }

    pub fn normalized(self: *const Self) Self {
        var new: Self = .copy(self);
        new.normalize();
        return new;
    }
};

test "Rotation normalization" {
    const r1: Rotation = .{ .x = 1, .y = 0, .z = 0 };
    try expectEqualDeep(Rotation{ .x = 1, .y = 0, .z = 0 }, r1.normalized());

    const r2: Rotation = .{ .x = 0, .y = 1, .z = 0 };
    try expectEqualDeep(Rotation{ .x = 0, .y = 1, .z = 0 }, r2.normalized());

    const r3: Rotation = .{ .x = 0, .y = 0, .z = 1 };
    try expectEqualDeep(Rotation{ .x = 0, .y = 0, .z = 1}, r3.normalized());

    const r4: Rotation = .{ .x = 1, .y = 1, .z = 0 };
    try expectEqualDeep(Rotation{ .x = math.sqrt1_2, .y = math.sqrt1_2, .z = 0 }, r4.normalized());

    const r5: Rotation = .{ .x = 1, .y = 0, .z = 1 };
    try expectEqualDeep(Rotation{ .x = math.sqrt1_2, .y = 0, .z = math.sqrt1_2 }, r5.normalized());

    const r6: Rotation = .{ .x = 0, .y = 1, .z = 1 };
    try expectEqualDeep(Rotation{ .x = 0, .y = math.sqrt1_2, .z = math.sqrt1_2 }, r6.normalized());

    const r7: Rotation = .{ .x = 1, .y = 1, .z = 1 };
    try expectEqualDeep(Rotation{ .x = 1.0 / @sqrt(3.0), .y = 1.0 / @sqrt(3.0), .z = 1.0 / @sqrt(3.0) }, r7.normalized());

    const r8: Rotation = .{ .x = 2, .y = 0, .z = 0 };
    try expectEqualDeep(Rotation{ .x = 1, .y = 0, .z = 0 }, r8.normalized());

    const r9: Rotation = .{ .x = 2, .y = 2, .z = 0 };
    try expectEqualDeep(Rotation{ .x = math.sqrt1_2, .y = math.sqrt1_2, .z = 0 }, r9.normalized());

    const r10: Rotation = .{ .x = 3, .y = 4, .z = 0 };
    try expectEqualDeep(Rotation{ .x = @as(f16, 3) / 5, .y = @as(f16, 4) / 5, .z = 0 }, r10.normalized());
}

pub fn Matrix(comptime T: type, row_count: usize, col_count: usize) type {
    comptime {
        assert(@typeInfo(T) == .float or @typeInfo(T) == .int, "Can't create matrix of type " ++ @typeName(T));
        assert(row_count != 0, "Can't create matrix with 0 rows.");
        assert(col_count != 0, "Can't create matrix with 0 cols.");
    }

    return struct {
        elements: [element_count]T = undefined,

        const Self = @This();
        const element_count = row_count * col_count;
        pub const rows = row_count;
        pub const cols = col_count;

        pub const Transpose = Matrix(T, cols, rows);

        /// All elements are undefined.
        pub const empty: Self = .{};

        /// All elements are initizalized to 0.
        pub const zeroes: Self = .{
            .elements = [_]T{0} ** element_count,
        };

        pub fn init(elements: [element_count]T) Self {
            return .{
                .elements = elements,
            };
        }

        pub fn copy(other: *const Self) Self {
            var new: Self = .empty;
            @memcpy(&new.elements, &other.elements);
            return new;
        }

        pub fn elementPtr(self: *Self) [*]const T {
            return @ptrCast(&self.elements);
        }

        // =================== Operate Inplace ===================

        pub fn operateInplace(self: *Self, comptime operation: Operation, other: *const Self) Self {
            switch (operation) {
                .add => for (self.elements, 0..) |e, i| self.setIndexUnchecked(i, e + other.getIndexUnchecked(i).*),
                .addWrapping => for (self.elements, 0..) |e, i| self.setIndexUnchecked(i, e +% other.getIndexUnchecked(i).*),
                .addSaturating => for (self.elements, 0..) |e, i| self.setIndexUnchecked(i, e +| other.getIndexUnchecked(i).*),

                .sub => for (self.elements, 0..) |e, i| self.setIndexUnchecked(i, e - other.getIndexUnchecked(i).*),
                .subWrapping => for (self.elements, 0..) |e, i| self.setIndexUnchecked(i, e -% other.getIndexUnchecked(i).*),
                .subSaturating => for (self.elements, 0..) |e, i| self.setIndexUnchecked(i, e -| other.getIndexUnchecked(i).*),

                .mul => for (self.elements, 0..) |e, i| self.setIndexUnchecked(i, e * other.getIndexUnchecked(i).*),
                .mulWrapping => for (self.elements, 0..) |e, i| self.setIndexUnchecked(i, e *% other.getIndexUnchecked(i).*),
                .mulSaturating => for (self.elements, 0..) |e, i| self.setIndexUnchecked(i, e *| other.getIndexUnchecked(i).*),

                .div => for (self.elements, 0..) |e, i| self.setIndexUnchecked(i, e / other.getIndexUnchecked(i).*),
            }

            return self;
        }

        // =================== Addition ===================

        pub fn add(self: *const Self, other: *const Self) Self {
            var result: Self = .empty;

            for (self.elements, 0..) |e, i| {
                result.setIndexUnchecked(i, e + other.getIndexUnchecked(i).*);
            }
            
            return result;
        }

        pub fn addWrapping(self: *const Self, other: *const Self) Self {
            var result: Self = .empty;

            for (self.elements, 0..) |e, i| {
                result.setIndexUnchecked(i, e +% other.getIndexUnchecked(i).*);
            }
            
            return result;
        }

        pub fn addSaturating(self: *const Self, other: *const Self) Self {
            var result: Self = .empty;

            for (self.elements, 0..) |e, i| {
                result.setIndexUnchecked(i, e +| other.getIndexUnchecked(i).*);
            }
            
            return result;
        }

        // =================== Subtraction ===================

        pub fn sub(self: *const Self, other: *const Self) Self {
            var result: Self = .empty;

            for (self.elements, 0..) |e, i| {
                result.setIndexUnchecked(i, e - other.getIndexUnchecked(i).*);
            }
            
            return result;
        }

        pub fn subWrapping(self: *const Self, other: *const Self) Self {
            var result: Self = .empty;

            for (self.elements, 0..) |e, i| {
                result.setIndexUnchecked(i, e -% other.getIndexUnchecked(i).*);
            }
            
            return result;
        }

        pub fn subSaturating(self: *const Self, other: *const Self) Self {
            var result: Self = .empty;

            for (self.elements, 0..) |e, i| {
                result.setIndexUnchecked(i, e -| other.getIndexUnchecked(i).*);
            }
            
            return result;
        }

        // =================== Dot Product ===================
        
        pub fn dotProduct(self: *const Self, comptime OM: type, other: *const OM) t: {
            switch (@typeInfo(OM)) {
                .vector => |info| {
                    if (info.child != T) 
                        @compileError(
                            std.fmt.comptimePrint("Can't calculate the dot product of the matrix of type \"{s}\" and the vector of type \"{s}\"",
                                .{@typeName(T), @typeName(info.child)})
                        );
                    if (info.len != cols)
                        @compileError(
                            std.fmt.comptimePrint("Can't calculate the dot product of the matrix ({d}x{d}) and the vector ({d})",
                                .{rows, cols, info.len})
                        );
                    break :t @Vector(info.len, T);
                },
                else => {
                    if (OM.rows != cols)
                        @compileError(
                            std.fmt.comptimePrint("Can't calculate the dot product of the matrices: {d}x{d} and {d}x{d}", 
                                .{rows, cols, OM.rows, OM.cols})
                        );
                    break :t Matrix(T, rows, OM.cols);
                },
            }
        } {
            switch (@typeInfo(OM)) {
                .vector => |info| {
                    var result: @Vector(info.len, T) = [_]T{0} ** info.len;

                    for (0..rows) |row| {
                        for (0..cols) |col| {
                            result[row] += self.getUnchecked(row, col).* * other[col];
                        }
                    }

                    return result;
                },
                else => {
                    var result: Matrix(T, rows, OM.cols) = .zeroes;

                    for (0..rows) |row| {
                        for (0..OM.cols) |col| {
                            for (0..cols) |i| {
                                result.getMutUnchecked(row, col).* += 
                                    self.getUnchecked(row, i).* * other.getUnchecked(i, col).*;
                            }
                        }
                    }

                    return result;
                },
            }
        }

        pub fn dotProductInPlace(self: *Self, other: *const Self) void {
            for (0..rows) |row| {
                var vals = [_]T{0} ** cols;

                if (cols <= 4) {
                    inline for (0..cols) |col| {
                        inline for (0..cols) |i| {
                            vals[col] += self.getUnchecked(row, i).* * other.getUnchecked(i, col).*;
                        }
                    }
                    inline for (0..cols) |col| self.getMutUnchecked(row, col).* = vals[col];
                } else {
                    for (0..cols) |col| {
                        for (0..cols) |i| {
                            vals[col] += self.getUnchecked(row, i).* * other.getUnchecked(i, col).*;
                        }
                    }
                    for (0..cols) |col| self.getMutUnchecked(row, col).* = vals[col];
                }
            }
        }

        // =================== Transform ===================

        pub fn applyTransformations(
            self: *Self,
            scale_vector: anytype,
            angle: anytype,
            rotation: ?Rotation,
            translate_vector: anytype
        ) void {
            // Scale
            if (
                @typeInfo(@TypeOf(scale_vector)) != .optional 
                and @TypeOf(scale_vector) != @TypeOf(null)
            ) {
                self.applyScale(scale_vector);
            }
            // Rotation
            if (
                @typeInfo(@TypeOf(angle)) != .optional 
                and @TypeOf(angle) != @TypeOf(null) 
                and rotation != null
            ) {
                self.applyRotation(angle, rotation.?);
            }
            // Translation
            if (
                @typeInfo(@TypeOf(translate_vector)) != .optional 
                and @TypeOf(translate_vector) != @TypeOf(null)
            ) {
                self.applyTranslation(translate_vector);
            }
        }

        pub fn transformed(
            self: *const Self, 
            scale_vector: anytype,
            angle: anytype,
            rotation: ?Rotation,
            vector: anytype
        ) Self {
            var new: Self = .copy(self);
            new.applyTransformations(scale_vector, angle, rotation, vector);
            return new;
        }

        // =================== Translate ===================

        pub fn applyTranslation(self: *Self, vector: anytype) void {
            comptime assert(@typeInfo(@TypeOf(vector)) == .vector, "Expected \"Vector\" got " ++ @typeName(@TypeOf(vector)));

            for (0..@typeInfo(@TypeOf(vector)).vector.len) |i| {
                if (i >= rows) break;
                self.getMutUnchecked(i, cols - 1).* += vector[i];
            }
        }

        pub fn translated(self: *const Self, vector: anytype) Self {
            var new: Self = .copy(self);
            new.applyTranslation(vector);
            return new;
        }

        // ===================  Rotate  ===================

        /// - angle: the angle in radians.
        ///
        /// [OpenGL](https://registry.khronos.org/OpenGL-Refpages/gl2.1/xhtml/glRotate.xml)
        pub fn applyRotation(self: *Self, angle: f32, rotation: Rotation) void {
            if (rows == 4 and cols == 4) {
                // const normalized_rotation = rotation.normalized();
                const normalized_rotation = rotation;
                const x = normalized_rotation.x;
                const y = normalized_rotation.y;
                const z = normalized_rotation.z;

                const c = math.cos(angle);
                const s = math.sin(angle);

                self.dotProductInPlace(&.init(.{
                    pow2(x)*(1-c)+c,      x*y*(1-c)-z*s,      x*z*(1-c)+y*s,    0,
                      y*x*(1-c)+z*s,    pow2(y)*(1-c)+c,      y*z*(1-c)-x*s,    0,
                      x*z*(1-c)-y*s,      y*z*(1-c)+x*s,    pow2(z)*(1-c)+c,    0,
                                  0,                   0,                 0,    1,
                }));
            } else {
                @compileError(std.fmt.comptimePrint("Didn't implement rotation for matrix {d}x{d}.", .{rows, cols}));
            }
        }

        /// - angle: the angle in radians.
        pub fn rotated(self: *const Self, angle: f32, rotation: Rotation) Self {
            var new: Self = .copy(self);
            new.applyRotation(angle, rotation);
            return new;
        }

        // ===================  Scale  ===================

        pub fn applyScale(self: *Self, vector: anytype) void {
            comptime assert(@typeInfo(@TypeOf(vector)) == .vector, "Parameter \"vector\" has to be of type Vector.");

            for (0..@typeInfo(@TypeOf(vector)).vector.len) |i| {
                if (i >= rows) break;
                self.getMutUnchecked(i, i).* *= vector[i];
            }
        }

        pub fn scaled(self: *const Self, vector: anytype) Self {
            comptime {
                if (@typeInfo(@TypeOf(vector)) != .vector)
                    @compileError("Parameter \"vector\" has to be of type Vector.");
            }

            var new: Self = .copy(self);
            new.applyScale(vector);
            return new;
        }

        // ===================   Equal   ===================

        pub fn eql(self: *const Self, other: *const Self) bool {
            if (self == other) return true;

            for (self.elements, 0..) |e, i| {
                if (switch (@typeInfo(T)) {
                    .int => e != other.elements[i],
                    .float => 
                        !(math.approxEqRel(T, e, other.elements[i], @sqrt(math.floatEps(T)) * 0.001)
                            or math.approxEqAbs(T, e, other.elements[i], math.floatEps(T))),
                    else => unreachable,
                }) {
                    // std.debug.print("{any} != {any}\n", .{e, other.elements[i]});
                    return false;
                }
            }

            return true;
        }

        // ===================   get/set   ===================

        pub fn setIndex(self: *Self, index: usize, value: T) error{IndexOutOfBound}!void {
            if (self.elements.len < index) return error.IndexOutOfBound;
            self.setIndexUnchecked(index, value);
        }

        pub fn setIndexUnchecked(self: *Self, index: usize, value: T) void {
            self.elements[index] = value;
        }

        pub fn setIndexComptime(self: *Self, comptime index: usize, value: T) void {
            comptime assert(
                element_count > index, 
                std.fmt.comptimePrint("Can't index matrix ({d}x{d}) at index {d}!", .{rows, cols, index}
            ));

            self.elements[index] = value;
        }


        pub fn getIndex(self: *const Self, index: usize) ?*const T {
            if (self.elements.len < index) return null;
            return self.getIndexUnchecked(index);
        }

        pub fn getIndexUnchecked(self: *const Self, index: usize) *const T {
            return &self.elements[index];
        }

        pub fn getIndexComptime(self: *const Self, comptime index: usize) *const T {
            comptime assert(
                element_count > index,
                std.fmt.comptimePrint("Can't index matrix ({d}x{d}) at index {d}!", .{rows, cols, index}
            ));

            return &self.elements[index];
        }

        pub fn getIndexMut(self: *Self, index: usize) ?*T {
            if (self.elements.len < index) return null;
            return self.getIndexMutUnchecked(index);
        }

        pub fn getIndexMutUnchecked(self: *Self, index: usize) *T {
            return &self.elements[index];
        }

        pub fn getIndexMutComptime(self: *Self, comptime index: usize) *T {
            comptime assert(
                element_count > index,
                std.fmt.comptimePrint("Can't index matrix ({d}x{d}) at index {d}!", .{rows, cols, index}
            ));

            return &self.elements[index];
        }


        pub fn set(self: *Self, row: usize, col: usize, value: T) error{IndexOutOfBound}!void {
            if (row >= rows or col >= cols) return error.IndexOutOfBound;
            self.setUnchecked(row, col, value);
        }
        
        pub fn setUnchecked(self: *Self, row: usize, col: usize, value: T) void {
            self.elements[flatIndexUnchecked(row, col)] = value;
        }

        pub fn setComptime(self: *Self, comptime row: usize, comptime col: usize, value: T) void {
            comptime assert(
                row < rows and col < cols,
                std.fmt.comptimePrint("Can't index matrix ({d}x{d}) at {d}x{d}!", .{rows, cols, row, col}
            ));

            self.elements[flatIndexComptime(row, col)] = value;
        }


        pub fn get(self: *const Self, row: usize, col: usize) ?*const T {
            if (row >= rows or col >= cols) return null;
            return self.getUnchecked(row, col);
        }
        
        pub fn getUnchecked(self: *const Self, row: usize, col: usize) *const T {
            return &self.elements[flatIndexUnchecked(row, col)];
        }

        pub fn getComptime(self: *const Self, comptime row: usize, comptime col: usize) *const T {
            comptime assert(
                row < rows and col < cols,
                std.fmt.comptimePrint("Can't index matrix ({d}x{d}) at {d}x{d}!", .{rows, cols, row, col}
            ));

            return *self.elements[flatIndexComptime(row, col)];
        }
         
        pub fn getMut(self: *Self, row: usize, col: usize) ?*const T {
            if (row >= rows or col >= cols) return null;
            return self.getMutUnchecked(row, col);
        }
        
        pub fn getMutUnchecked(self: *Self, row: usize, col: usize) *T {
            return &self.elements[flatIndexUnchecked(row, col)];
        }

        pub fn getMutComptime(self: *Self, comptime row: usize, comptime col: usize) *T {
            comptime assert(
                row < rows and col < cols,
                std.fmt.comptimePrint("Can't index matrix ({d}x{d}) at {d}x{d}!", .{rows, cols, row, col}
            ));

            return *self.elements[flatIndexComptime(row, col)];
        }
         
        // ================= Index|row/col =================

        pub fn flatIndex(row: usize, col: usize) ?usize {
            if (row >= rows or col >= cols) return null;
            return flatIndexUnchecked(row, col);
        }

        pub fn flatIndexUnchecked(row: usize, col: usize) usize {
            return cols * row + col;
        }

        pub fn flatIndexComptime(comptime row: usize, comptime col: usize) usize {
            comptime assert(
                row < rows and col < cols,
                std.fmt.comptimePrint("Can't index matrix ({d}x{d}) at {d}x{d}!", .{rows, cols, row, col}
            ));

            return comptime cols * row + col;
        }


        pub fn rowFromIndexUnchecked(index: usize) usize {
            return index / cols;
        }
        

        pub fn colFromIndexUnchecked(index: usize) usize {
            return index % cols;
        }


        pub fn format(
            self: Self,
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            var col_width: usize = 1;

            for (0..rows) |row| {
                for (0..cols) |col| {
                    const element_width = elementWidth(self.getUnchecked(row, col).*);
                    if (element_width > col_width) col_width = element_width;
                }
            }

            // width of all cols + width of spaces and commas...
            const row_width = col_width * cols + cols * 2;

            try writer.writeAll("┌");
            for (0..row_width) |_| try writer.writeByte(' ');
            try writer.writeAll("┐\n");

            for (0..rows) |row| {
                try writer.writeAll("│ ");
                for (0..cols) |col| {
                    if (col != 0) try writer.writeAll(", ");
                    const element_width = elementWidth(self.getUnchecked(row, col).*);

                    for (0..col_width - element_width) |_| try writer.writeByte(' ');

                    switch (@typeInfo(T)) {
                        .int => try writer.print("{d}", .{self.getUnchecked(row, col).*}),
                        .float => try writer.print("{d:.2}", .{self.getUnchecked(row, col).*}),
                        else => unreachable,
                    }
                }
                try writer.writeAll(" │\n");
            }

            try writer.writeAll("└");
            for (0..row_width) |_| try writer.writeByte(' ');
            try writer.writeAll("┘\n");
        }

        fn elementWidth(element: T) usize {
            const sign: usize = if (element < 0) 1 else 0;

            return switch (@typeInfo(T)) {
                .int => if (element == 0) 1 + sign else math.log10(@abs(element)) + 1 + sign,
                .float => {
                    const e = @as(usize, @intFromFloat(@abs(element)));
                    return if (e == 0) 4 + sign else math.log10(e) + 4 + sign;
                },
                else => unreachable,
            };
        }
    };
}

test "Matrix addition" {
    var mat1: Matrix(i32, 2, 2) = .init(.{
        0, 0,
        0, 0,
    });
    var mat2: Matrix(i32, 2, 2) = .init(.{
        1, 2,
        3, 4,
    });
    var mat3: Matrix(i32, 2, 2) = .init(.{
        -1, -2,
        -3, -4,
    });
    var mat4: Matrix(i32, 2, 2) = .init(.{
        9, 7,
        1, 4,
    });

    try expect(mat1.add(&mat2).eql(&.init(.{
        1, 2, 
        3, 4,
    })));
    try expect(mat1.add(&mat3).eql(&.init(.{
        -1, -2, 
        -3, -4,
    })));
    try expect(mat1.add(&mat4).eql(&.init(.{
        9, 7, 
        1, 4,
    })));

    var mat5: Matrix(u8, 2, 2) = .init(.{
        255, 0,
        0, 255,
    });
    var mat6: Matrix(u8, 2, 2) = .init(.{
        5, 12,
        8, 10,
    });
    var mat7: Matrix(u8, 2, 2) = .init(.{
        142, 11,
        5, 188,
    });
    var mat8: Matrix(u8, 2, 2) = .init(.{
        42, 12,
        58, 17,
    });

    try expect(mat5.addSaturating(&mat6).eql(&.init(.{
        255, 12,
        8, 255,
    })));
    try expect(mat6.addSaturating(&mat8).eql(&.init(.{
        47, 24,
        66, 27,
    })));
    try expect(mat5.addWrapping(&mat7).eql(&.init(.{
        141, 11,
        5, 187,
    })));
}

test "Matrix subtraction" {
    var mat1: Matrix(i32, 2, 2) = .init(.{
        0, 0,
        0, 0,
    });
    var mat2: Matrix(i32, 2, 2) = .init(.{
        1, 2,
        3, 4,
    });
    var mat3: Matrix(i32, 2, 2) = .init(.{
        -1, -2,
        -3, -4,
    });
    var mat4: Matrix(i32, 2, 2) = .init(.{
        9, 7,
        1, 4,
    });

    try expect(mat1.sub(&mat2).eql(&.init(.{
        -1, -2, 
        -3, -4,
    })));
    try expect(mat1.sub(&mat3).eql(&.init(.{
        1, 2, 
        3, 4,
    })));
    try expect(mat1.sub(&mat4).eql(&.init(.{
        -9, -7, 
        -1, -4,
    })));

    var mat5: Matrix(u32, 2, 2) = .init(.{
        0, 0,
        0, 0,
    });
    var mat6: Matrix(u32, 2, 2) = .init(.{
        5, 12,
        8, 10,
    });
    var mat7: Matrix(u32, 2, 2) = .init(.{
        142, 11,
        5, 188,
    });
    var mat8: Matrix(u32, 2, 2) = .init(.{
        42, 12,
        58, 17,
    });

    try expect(mat5.subSaturating(&mat6).eql(&.init(.{
        0, 0,
        0, 0,
    })));
    try expect(mat6.subSaturating(&mat8).eql(&.init(.{
        0, 0,
        0, 0,
    })));
    try expect(mat5.subWrapping(&mat7).eql(&.init(.{
        math.maxInt(u32) - 141, math.maxInt(u32) - 10,
        math.maxInt(u32) - 4, math.maxInt(u32) - 187,
    })));
}

test "Matrix dot product" {
    var mat1: Matrix(u32, 3, 3) = .init(.{
        4, 2, 0,
        0, 8, 1,
        0, 1, 0,
    });
    var mat2: Matrix(u32, 3, 3) = .init(.{
        4, 2, 1,
        2, 0, 4,
        9, 4, 2,
    });

    var dot_product1x2 = mat1.dotProduct(@TypeOf(mat2), &mat2);

    try expect(dot_product1x2.eql(&.init(.{
        20, 8, 12,
        25, 4, 34,
         2, 0,  4,
    })));

    mat1.dotProductInPlace(&mat2);
    try expect(mat1.eql(&.init(.{
        20, 8, 12,
        25, 4, 34,
         2, 0,  4,
    })));

    var mat3: Matrix(f32, 3, 2) = .init(.{
        3.33, 10.5,
        42.0, 15.2,
        18.9, 33.3,
    });
    var mat4: Matrix(f32, 2, 3) = .init(.{
        1.13, 15.1, 58.2,
        34.2, 4.32, 5.12,
    });

    var dot_product3x4 = mat3.dotProduct(@TypeOf(mat4), &mat4);

    try expect(dot_product3x4.eql(&.init(.{
        362.8629, 95.643, 247.566,
        567.3, 699.864, 2522.224,
        1160.217, 429.24603, 1270.476,
    })));
}

test "Matrix transforming" {
    var mat1: Matrix(f32, 4, 4) = glm.identity(1);
    var mat2: Matrix(f32, 4, 4) = glm.identity(1);

    const scaler = @Vector(3, f32){3.0, 2.0, 1.0};
    const angle = math.degreesToRadians(90);
    const rotation = .{ .z = 1 };
    const translator = @Vector(3, f32){1.0, 2.0, 3.0};

    mat2.applyTransformations(scaler, angle, rotation, translator);

    var mat1_scaled = mat1.scaled(scaler);
    mat1.applyScale(scaler);
    try expect(mat1.eql(&.init(.{
        3, 0, 0, 0,
        0, 2, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    })));
    try expect(mat1.eql(&mat1_scaled));

    var mat1_rotated1 = mat1.rotated(angle, rotation);
    mat1.applyRotation(angle, rotation);
    try expect(mat1.eql(&.init(.{
        0, -3, 0, 0,
        2,  0, 0, 0,
        0,  0, 1, 0,
        0,  0, 0, 1,
    })));
    try expect(mat1.eql(&mat1_rotated1));

    var mat1_translated = mat1.translated(translator);
    mat1.applyTranslation(translator);
    try expect(mat1.eql(&.init(.{
        0, -3, 0, 1,
        2,  0, 0, 2,
        0,  0, 1, 3,
        0,  0, 0, 1,
    })));
    try expect(mat1.eql(&mat1_translated));

    try expect(mat1.eql(&mat2));
}

test "Matrix equal" {
    var mat1: Matrix(u32, 3, 3) = .init(.{
        4, 2, 0,
        0, 8, 1,
        0, 1, 0,
    });
    var mat2: Matrix(u32, 3, 3) = .init(.{
        4, 2, 0,
        0, 8, 1,
        0, 1, 0,
    });
    var mat3: Matrix(u32, 3, 3) = .init(.{
        0, 0, 0,
        0, 0, 0,
        0, 0, 0,
    });

    try expect(mat1.eql(&mat1));
    try expect(mat1.eql(&mat2));
    try expect(!mat1.eql(&mat3));
}

test "Matrix get/set with index or row/col" {
    var mat1: Matrix(u1, 2, 2) = .zeroes;

    try expect(mat1.eql(&.init(.{0, 0, 0, 0})));

    try mat1.set(0, 0, 1);
    try expect(mat1.eql(&.init(.{1, 0, 0, 0})));
    try expectEqual(mat1.set(0, 2, 1), error.IndexOutOfBound);

    try expectEqual(mat1.getUnchecked(1, 0).*, 0);
    try expectEqual(mat1.get(1, 0), mat1.getIndex(2));

    mat1.setComptime(1, 0, 1);
    try expectEqual(mat1.getIndexUnchecked(2).*, 1);

    mat1.setIndexComptime(2, 0);
    try expectEqual(mat1.getUnchecked(1, 0).*, 0);
}

test "Matrix index to col/col & vice versa" {
    var mat1: Matrix(u32, 4, 4) = .empty;
    _ = &mat1;

    // mat 4x4: row & col to index
    try expectEqual(@TypeOf(mat1).flatIndex(0, 0), 0);
    try expectEqual(@TypeOf(mat1).flatIndex(0, 1), 1);
    try expectEqual(@TypeOf(mat1).flatIndex(1, 1), 5);
    try expectEqual(@TypeOf(mat1).flatIndex(3, 0), 12);
    try expectEqual(@TypeOf(mat1).flatIndex(3, 3), 15);
    try expectEqual(@TypeOf(mat1).flatIndex(3, 10), null);
    try expectEqual(@TypeOf(mat1).flatIndex(4, 2), null);

    // mat 4x4: index to row
    try expectEqual(@TypeOf(mat1).rowFromIndexUnchecked(0), 0);
    try expectEqual(@TypeOf(mat1).rowFromIndexUnchecked(3), 0);
    try expectEqual(@TypeOf(mat1).rowFromIndexUnchecked(4), 1);
    try expectEqual(@TypeOf(mat1).rowFromIndexUnchecked(8), 2);
    try expectEqual(@TypeOf(mat1).rowFromIndexUnchecked(12), 3);
    try expectEqual(@TypeOf(mat1).rowFromIndexUnchecked(15), 3);

    // mat 4x4: index to col
    try expectEqual(@TypeOf(mat1).colFromIndexUnchecked(0), 0);
    try expectEqual(@TypeOf(mat1).colFromIndexUnchecked(3), 3);
    try expectEqual(@TypeOf(mat1).colFromIndexUnchecked(4), 0);
    try expectEqual(@TypeOf(mat1).colFromIndexUnchecked(9), 1);
    try expectEqual(@TypeOf(mat1).colFromIndexUnchecked(14), 2);
    try expectEqual(@TypeOf(mat1).colFromIndexUnchecked(15), 3);

    var mat2: Matrix(u32, 3, 4) = .empty;
    _ = &mat2;

    // mat 3x4: row & col to index
    try expectEqual(@TypeOf(mat2).flatIndex(0, 0), 0);
    try expectEqual(@TypeOf(mat2).flatIndex(0, 1), 1);
    try expectEqual(@TypeOf(mat2).flatIndex(1, 1), 5);
    try expectEqual(@TypeOf(mat2).flatIndex(2, 0), 8);
    try expectEqual(@TypeOf(mat2).flatIndex(3, 0), null);

    // mat 3x4: index to row
    try expectEqual(@TypeOf(mat2).rowFromIndexUnchecked(0), 0);
    try expectEqual(@TypeOf(mat2).rowFromIndexUnchecked(3), 0);
    try expectEqual(@TypeOf(mat2).rowFromIndexUnchecked(4), 1);
    try expectEqual(@TypeOf(mat2).rowFromIndexUnchecked(8), 2);
    try expectEqual(@TypeOf(mat2).rowFromIndexUnchecked(12), 3);

    // mat 3x4: index to col
    try expectEqual(@TypeOf(mat2).colFromIndexUnchecked(0), 0);
    try expectEqual(@TypeOf(mat2).colFromIndexUnchecked(3), 3);
    try expectEqual(@TypeOf(mat2).colFromIndexUnchecked(4), 0);
    try expectEqual(@TypeOf(mat2).colFromIndexUnchecked(9), 1);

    var mat3: Matrix(u32, 4, 3) = .empty;
    _ = &mat3;

    // mat 4x3: row & col to index
    try expectEqual(@TypeOf(mat3).flatIndex(0, 0), 0);
    try expectEqual(@TypeOf(mat3).flatIndex(0, 2), 2);
    try expectEqual(@TypeOf(mat3).flatIndex(1, 1), 4);
    try expectEqual(@TypeOf(mat3).flatIndex(2, 0), 6);
    try expectEqual(@TypeOf(mat3).flatIndex(2, 3), null);

    // mat 4x3: index to row
    try expectEqual(@TypeOf(mat3).rowFromIndexUnchecked(0), 0);
    try expectEqual(@TypeOf(mat3).rowFromIndexUnchecked(3), 1);
    try expectEqual(@TypeOf(mat3).rowFromIndexUnchecked(4), 1);
    try expectEqual(@TypeOf(mat3).rowFromIndexUnchecked(8), 2);
    try expectEqual(@TypeOf(mat3).rowFromIndexUnchecked(12), 4);

    // mat 4x3: index to col
    try expectEqual(@TypeOf(mat3).colFromIndexUnchecked(0), 0);
    try expectEqual(@TypeOf(mat3).colFromIndexUnchecked(3), 0);
    try expectEqual(@TypeOf(mat3).colFromIndexUnchecked(4), 1);
    try expectEqual(@TypeOf(mat3).colFromIndexUnchecked(9), 0);
}
