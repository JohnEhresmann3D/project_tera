local StateManager = {}
StateManager.__index = StateManager

local function callIfExists(obj, method, ...)
    if obj and obj[method] then
        return obj[method](obj, ...)
    end
end

function StateManager.new()
    return setmetatable({
        states = {},
        currentName = nil,
        currentState = nil,
    }, StateManager)
end

function StateManager:register(name, state)
    self.states[name] = state
end

function StateManager:switch(name, payload)
    local nextState = self.states[name]
    assert(nextState, "Unknown state: " .. tostring(name))

    local prevName = self.currentName
    local prevState = self.currentState
    callIfExists(prevState, "onExit", name, payload)

    self.currentName = name
    self.currentState = nextState
    callIfExists(nextState, "onEnter", prevName, payload)
end

function StateManager:getCurrentName()
    return self.currentName
end

function StateManager:update(dt)
    callIfExists(self.currentState, "update", dt)
end

function StateManager:draw()
    callIfExists(self.currentState, "draw")
end

function StateManager:keypressed(key)
    callIfExists(self.currentState, "keypressed", key)
end

function StateManager:mousemoved(x, y, dx, dy)
    callIfExists(self.currentState, "mousemoved", x, y, dx, dy)
end

function StateManager:mousepressed(x, y, button)
    callIfExists(self.currentState, "mousepressed", x, y, button)
end

function StateManager:resize(w, h)
    callIfExists(self.currentState, "resize", w, h)
end

function StateManager:textinput(text)
    callIfExists(self.currentState, "textinput", text)
end

return StateManager
