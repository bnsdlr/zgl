const std = @import("std");

pub const matrices = @import("glm/matrices.zig");
pub const Matrix = matrices.Matrix;
pub const Matrix4 = Matrix(f32, 4, 4);

pub const Vec4 = @Vector(4, f32);
pub const Vec3 = @Vector(3, f32);

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
