-- GPU shader for 3D voxel rendering: vertex transform + linear fog
-- Compiles a Love2D GLSL3 shader with view/projection uniforms and distance fog.

local Shader = {}

---------------------------------------------------------------------------
-- GLSL source
---------------------------------------------------------------------------

local vertexSource = [[
#pragma language glsl3

// Uniforms
uniform mat4 u_view;
uniform mat4 u_proj;

// Fog distance varying (custom)
varying float v_fogDist;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    // Transform world position into view space
    vec4 viewPos = u_view * vec4(vertex_position.xyz, 1.0);

    // Camera distance for fog (length in view space)
    v_fogDist = length(viewPos.xyz);

    // Pass vertex color through Love2D's built-in varying
    VaryingColor = VertexColor;

    // Project into clip space
    vec4 clipPos = u_proj * viewPos;
    return clipPos;
}
]]

local fragmentSource = [[
#pragma language glsl3

// Fog uniforms
uniform float u_fogStart;  // distance where fog begins (default ~80)
uniform float u_fogEnd;    // distance where fog is fully opaque (default ~160)
uniform vec3  u_fogColor;  // sky / fog color (default 0.45, 0.65, 0.85)

// Fog distance varying (custom)
varying float v_fogDist;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    // Linear fog factor: 1.0 = no fog, 0.0 = fully fogged
    float fogFactor = clamp(
        (u_fogEnd - v_fogDist) / (u_fogEnd - u_fogStart),
        0.0, 1.0
    );

    // color = VaryingColor (vertex color passed through from vertex shader)
    vec3 finalRGB = mix(u_fogColor, color.rgb, fogFactor);

    return vec4(finalRGB, color.a);
}
]]

---------------------------------------------------------------------------
-- Compile and return the shader, setting sane defaults on the uniforms
---------------------------------------------------------------------------

--- Compile the 3D voxel shader.
--- @return love.Shader  The compiled shader with fog uniforms pre-set to defaults.
function Shader.compile()
    local s = love.graphics.newShader(vertexSource, fragmentSource)

    -- Set fog defaults so the shader is usable immediately
    local C = require("src.constants")
    s:send("u_fogStart", C.FOG_START)
    s:send("u_fogEnd",   C.FOG_END)
    s:send("u_fogColor", { 0.45, 0.65, 0.85 })

    return s
end

return Shader
