-- App entrypoint:
-- Wires LOVE callbacks into a lightweight state machine.
-- All gameplay/render logic lives inside registered states.
local GameState = require("src.state.game_state")
local StateManager = require("src.state.state_manager")
local MenuState = require("src.ui.main_menu")
local PlayingState = require("src.state.states.playing_state")
local PausedState = require("src.state.states.paused_state")

local stateManager

function love.load()
    -- Single state manager instance for the whole app lifetime.
    stateManager = StateManager.new()
    stateManager:register(GameState.MENU, MenuState.new(stateManager))
    stateManager:register(GameState.PLAYING, PlayingState.new(stateManager))
    stateManager:register(GameState.PAUSED, PausedState.new(stateManager))
    stateManager:switch(GameState.MENU)
end

function love.update(dt)
    stateManager:update(dt)
end

function love.draw()
    stateManager:draw()
end

function love.mousemoved(x, y, dx, dy)
    stateManager:mousemoved(x, y, dx, dy)
end

function love.mousepressed(x, y, button)
    stateManager:mousepressed(x, y, button)
end

function love.keypressed(key)
    stateManager:keypressed(key)
end

function love.resize(w, h)
    stateManager:resize(w, h)
end

function love.textinput(text)
    stateManager:textinput(text)
end
