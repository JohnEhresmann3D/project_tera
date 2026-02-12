local GameState = require("src.state.game_state")
local Input3D = require("src.player.input3d")

-- Lightweight pause overlay state.
-- Stores enough context to resume the previous state with same seed payload.
-- No simulation updates happen here; it is purely input + overlay UI.
local PausedState = {}
PausedState.__index = PausedState

function PausedState.new(stateManager)
    return setmetatable({
        stateManager = stateManager,
        previous = GameState.PLAYING,
        seed = nil,
    }, PausedState)
end

function PausedState:onEnter(_, payload)
    self.previous = (payload and payload.previous) or GameState.PLAYING
    self.seed = payload and payload.seed or self.seed
    -- Return cursor to OS while paused.
    Input3D.setCapture(false)
    love.mouse.setVisible(true)
end

function PausedState:keypressed(key)
    if key == "escape" or key == "return" then
        self.stateManager:switch(self.previous, { seed = self.seed })
        return
    end

    if key == "q" then
        love.event.quit()
    end
end

function PausedState:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Paused", 0, 180, love.graphics.getWidth(), "center")
    love.graphics.printf("Enter/Escape: Resume    Q: Quit", 0, 220, love.graphics.getWidth(), "center")
end

return PausedState
