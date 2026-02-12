local sqrt = math.sqrt

local Input = {}

-- WASD mapped to isometric world directions:
-- W = move toward top-right of world (decrease both wx,wy in screen = NW in world)
-- S = move toward bottom-left (increase both wx,wy = SE in world)
-- A = move toward top-left (decrease wx, increase wy = SW in world)
-- D = move toward bottom-right (increase wx, decrease wy = NE in world)
function Input.getMovementVector()
    local dx, dy = 0, 0

    if love.keyboard.isDown("w") then dx = dx - 1; dy = dy - 1 end
    if love.keyboard.isDown("s") then dx = dx + 1; dy = dy + 1 end
    if love.keyboard.isDown("a") then dx = dx - 1; dy = dy + 1 end
    if love.keyboard.isDown("d") then dx = dx + 1; dy = dy - 1 end

    -- Normalize diagonal movement
    local len = sqrt(dx * dx + dy * dy)
    if len > 0 then
        dx = dx / len
        dy = dy / len
    end

    return dx, dy
end

return Input
