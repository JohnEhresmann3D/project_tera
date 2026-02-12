-- 4x4 matrix math (column-major flat table of 16 floats)
-- Layout: m[1..4] = col0, m[5..8] = col1, m[9..12] = col2, m[13..16] = col3
-- Matches GLSL/Love2D convention

local sin = math.sin
local cos = math.cos
local tan = math.tan
local rad = math.rad

local Matrix = {}

function Matrix.identity()
    return {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    }
end

function Matrix.multiply(a, b)
    local out = {}
    for col = 0, 3 do
        for row = 1, 4 do
            local sum = 0
            for k = 0, 3 do
                sum = sum + a[k * 4 + row] * b[col * 4 + k + 1]
            end
            out[col * 4 + row] = sum
        end
    end
    return out
end

-- Perspective projection matrix
-- fovY in degrees, aspect = width/height
function Matrix.perspective(fovY, aspect, near, far)
    local f = 1.0 / tan(rad(fovY) * 0.5)
    local nf = 1.0 / (near - far)
    -- Negate Y scale: Love2D canvases have flipped Y vs standard OpenGL
    return {
        f / aspect, 0, 0, 0,
        0, -f, 0, 0,
        0, 0, (far + near) * nf, -1,
        0, 0, 2 * far * near * nf, 0,
    }
end

-- First-person view matrix from eye position + yaw/pitch (radians)
-- yaw: rotation around Y axis (0 = looking toward -Z)
-- pitch: rotation around X axis (positive = look up)
function Matrix.fpView(eyeX, eyeY, eyeZ, yaw, pitch)
    local cy, sy = cos(yaw), sin(yaw)
    local cp, sp = cos(pitch), sin(pitch)

    -- Forward = (-sin(yaw)*cos(pitch), sin(pitch), -cos(yaw)*cos(pitch))
    -- Right   = (cos(yaw), 0, -sin(yaw))
    -- Up      = cross(right, forward)

    local rx, ry, rz = cy, 0, -sy
    local fx, fy, fz = -sy * cp, sp, -cy * cp
    -- up = right x forward
    local ux = ry * fz - rz * fy
    local uy = rz * fx - rx * fz
    local uz = rx * fy - ry * fx

    -- View matrix = transpose(rotation) * translate(-eye)
    local tx = -(rx * eyeX + ry * eyeY + rz * eyeZ)
    local ty = -(ux * eyeX + uy * eyeY + uz * eyeZ)
    local tz = -(-fx * eyeX + -fy * eyeY + -fz * eyeZ)

    return {
        rx,  ux, -fx, 0,
        ry,  uy, -fy, 0,
        rz,  uz, -fz, 0,
        tx,  ty,  tz, 1,
    }
end

-- Forward direction vector (unit, yaw+pitch)
function Matrix.forwardDir(yaw, pitch)
    local cp = cos(pitch)
    return -sin(yaw) * cp, sin(pitch), -cos(yaw) * cp
end

-- Right direction vector (unit, yaw only, horizontal)
function Matrix.rightDir(yaw)
    return cos(yaw), 0, -sin(yaw)
end

return Matrix
