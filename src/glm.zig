const std = @import("std");
const math = std.math;

const expectEqualDeep = std.testing.expectEqualDeep;

pub const matrices = @import("glm/matrices.zig");
pub const Matrix = matrices.Matrix;
pub const Matrix4 = Matrix(f32, 4, 4);

pub const Vec4 = @Vector(4, f32);
pub const Vec3 = @Vector(3, f32);

fn pow2(x: f32) f32 {
    return math.pow(f32, x, 2);
}

/// Creates a new identity matrix.
/// 
/// # Parameters
///
/// - `T`:      Specifies the type of the resulting identity matrix.
/// - `value`:  Specifies the `identity`.
///
/// # Example
///
/// ```zig
/// const mat: Matrix(f32, 4, 4) = identity(1.0);
/// try std.testing.expect(mat.eql(&.init(.{
///     1.0, 0.0, 0.0, 0.0,
///     0.0, 1.0, 0.0, 0.0,
///     0.0, 0.0, 1.0, 0.0,
///     0.0, 0.0, 0.0, 1.0,
/// })));
/// ```
pub fn identity(value: f32) Matrix4 {
    var new: Matrix(f32, 4, 4) = .zeroes;
    for (0..4) |i| new.setUnchecked(i, i, value);
    return new;
}

/// Creates an orthographic projection matrix from the given parameters.
/// The matrix transforms all the given coordinates to clip coordinates by
/// directly projecting them onto the near plane. The parameters define the
/// orthographic frustum that represents the shape where all visible
/// coordinates should be.
///
/// More information can be found [here](https://en.wikipedia.org/wiki/Orthographic_projection).
///
/// [OpenGL Doc](https://registry.khronos.org/OpenGL-Refpages/gl2.1/xhtml/glOrtho.xml)
///
/// # Parameters
///
/// - `left`:   Specifies the left coordinate of the orthographic frustum.
/// - `right`:  Specifies the right coordinate of the orthographic frustum.
/// - `bottom`: Specifies the bottom coordinate of the orthographic frustum.
/// - `top`:    Specifies the top coordinate of the orthographic frustum.
/// - `near`:   Specifies the near plane of the orthographic frustum.
///             All coordinates in front of the near plane will not be drawn.
/// - `far`:    Specifies the far plane of the orthographic frustum.
///             All coordinates behind the far plane will not be drawn.
pub fn ortho(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Matrix4 {
    return .init(.{
        2 / (right - left), 0,                  0,                  -(right + left) / (right - left),
        0,                  2 / (top - bottom), 0,                  -(top + bottom) / (top - bottom),
        0,                  0,                  -2 / (far - near),  -(far + near) / (far - near),
        0,                  0,                  0,                  1,
    });
}

/// Creates a perspective projection matrix from the given parameters.
/// The matrix transforms all the given coordinates to clip coordinates
/// and transforms the w component of the vectors such that after
/// *perspective division* is applied, the resulting objects will have
/// perspective. The parameters define the *perspective frustum* that
/// represents the shape where all visible coordinates should be.
///
/// [OpenGl Doc](https://registry.khronos.org/OpenGL-Refpages/gl2.1/xhtml/gluPerspective.xml)
///
/// # Parameters
///
/// - `fov`:    Specifies the *Field of View* in radians that sets the width
///             of the perspective frustum. Increasing or decreasing this
///             value will give the visual effect of *zooming* in.
/// - `aspect`: Specifies the aspect ratio of your scene that sets the height
///             of the perspective frustum. When changing window coordinates
///             it is a good idea to manage the aspect ratio (keep it
///             constant or allow for all ratios).
/// - `near`:   Specifies the near plane of the perspective frustum.
///             All coordinates in front of the near plane will not be drawn.
/// - `far`:    Specifies the far plane of the perspective frustum.
///             All coordinates behind the far plane will not be drawn.
pub fn perspective(fov: f32, aspect: f32, near: f32, far: f32) Matrix4 {
    // cotangent(fov / 2) 
    // cotangent(x) = 1 / tan(x)
    const f = 1 / std.math.tan(fov / 2);
    return .init(.{
        f / aspect, 0, 0, 0,
        0, f, 0, 0,
        0, 0, (far + near) / (near - far), (2 * far * near) / (near - far),
        0, 0, -1, 0,
    });
}

pub fn normalize(vec: *Vec3) void {
    const magnitude: f32 = @floatCast(@sqrt(pow2(vec[0]) + pow2(vec[1]) + pow2(vec[2])));

    if (math.approxEqRel(f32, magnitude, 1.0, @sqrt(math.floatEps(f32)))) return;

    vec[0] /= magnitude;
    vec[1] /= magnitude;
    vec[2] /= magnitude;
}

pub fn normalized(vec: Vec3) Vec3 {
    var v = vec;
    normalize(&v);
    return v;
}

test normalize {
    var v1: Vec3 = .{ 1, 0, 0 };
    _ = &v1;
    try expectEqualDeep(Vec3{ 1, 0, 0 }, normalized(v1));

    var v2: Vec3 = .{ 0, 1, 0 };
    _ = &v2;
    try expectEqualDeep(Vec3{ 0, 1, 0 }, normalized(v2));

    var v3: Vec3 = .{ 0, 0, 1 };
    _ = &v3;
    try expectEqualDeep(Vec3{ 0, 0, 1}, normalized(v3));

    var v4: Vec3 = .{ 1, 1, 0 };
    _ = &v4;
    try expectEqualDeep(Vec3{ math.sqrt1_2, math.sqrt1_2, 0 }, normalized(v4));

    var v5: Vec3 = .{ 1, 0, 1 };
    _ = &v5;
    try expectEqualDeep(Vec3{ math.sqrt1_2, 0, math.sqrt1_2 }, normalized(v5));

    var v6: Vec3 = .{ 0, 1, 1 };
    _ = &v6;
    try expectEqualDeep(Vec3{ 0, math.sqrt1_2, math.sqrt1_2 }, normalized(v6));

    var v7: Vec3 = .{ 1, 1, 1 };
    _ = &v7;
    try expectEqualDeep(Vec3{ 1.0 / @sqrt(3.0), 1.0 / @sqrt(3.0), 1.0 / @sqrt(3.0) }, normalized(v7));

    var v8: Vec3 = .{ 2, 0, 0 };
    _ = &v8;
    try expectEqualDeep(Vec3{ 1, 0, 0 }, normalized(v8));

    var v9: Vec3 = .{ 2, 2, 0 };
    _ = &v9;
    try expectEqualDeep(Vec3{ math.sqrt1_2, math.sqrt1_2, 0 }, normalized(v9));

    // var v10: Vec3 = .{ 3, 4, 0 };
    // _ = &v10;
    // try expectEqualDeep(Vec3{ @as(f16, 3) / 5, @as(f16, 4) / 5, 0 }, normalized(v10));
}

pub fn cross(a: Vec3, b: Vec3) Vec3 {
    return Vec3{
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    };
    // const A = @TypeOf(a);
    // const B = @TypeOf(b);
    //
    // switch (@typeInfo(A)) {
    //     .vector => |a_info| {
    //         switch (@typeInfo(B)) {
    //             .vector => |b_info| {
    //                 if (a_info.len != b_info.len or a_info.child != b_info.child) 
    //                     @compileError("Cannot calculate the cross product for " 
    //                         ++ @typeName(A) ++ " x " ++ @typeName(B));
    //
    //                 if (a_info.len == 3) {
    //                 } else {
    //                     @compileError("Did not implement cross product for vectors of length " 
    //                         ++ a_info.len);
    //                 }
    //             },
    //             .@"struct" => |_| {
    //             },
    //             else => @compileError(
    //                 "Cross product is not implemented for " ++ @typeName(A) ++ " x " ++ @typeName(B)),
    //         }
    //     },
    //     .@"struct" => |_| {
    //     },
    //     else => @compileError("Corss product is only implemented for Matrices and Vectors."),
    // }
}

pub fn lookAt(pos: Vec3, target: Vec3, world_up: Vec3) Matrix4 {
    // z-axis
    const direction: Vec3 = normalized(pos - target);
    // postitive x-axis
    const right: Vec3 = normalized(cross(normalized(world_up), direction));
    // y-axis
    const up: Vec3 = cross(direction, right);

    const translation: Matrix4 = .init(.{
        right[0], right[1], right[2], 0,
        up[0], up[1], up[2], 0,
        direction[0], direction[1], direction[2], 0,
        0, 0, 0, 1,
    });

    const rotation: Matrix4 = .init(.{
        1, 0, 0, -pos[0],
        0, 1, 0, -pos[1],
        0, 0, 1, -pos[2],
        0, 0, 0, 1,
    });

    // this makes you spin around pos...
    // return rotation.dotProduct(Matrix4, &translation);
    return translation.dotProduct(Matrix4, &rotation);
}

// pub fn direction(pitch: f32, yaw: f32) Vec3 {
//     return .{
//         math.cos(math.degreesToRadians(yaw)) * math.cos(math.degreesToRadians(pitch)),
//         math.cos(math.degreesToRadians(pitch)),
//         math.sin(math.degreesToRadians(yaw)) * math.cos(math.degreesToRadians(pitch)),
//     };
// }
