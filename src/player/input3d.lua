-- 3D input handler (singleton)
-- Manages mouse capture and forwards raw mouse deltas to Camera3D for look.

local Input3D = {}
local camera  = nil
local captured = true

function Input3D.init(camera3d)
    camera = camera3d
    love.mouse.setRelativeMode(true)
    captured = true
end

function Input3D.mousemoved(dx, dy)
    if captured and camera then
        camera:mouseLook(dx, dy)
    end
end

function Input3D.toggleCapture()
    captured = not captured
    love.mouse.setRelativeMode(captured)
end

function Input3D.isCaptured()
    return captured
end

return Input3D
