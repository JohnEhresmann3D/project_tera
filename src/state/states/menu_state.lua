local GameState = require("src.state.game_state")
local UI = require("src.ui.ui")
local Input3D = require("src.player.input3d")
local bit = require("bit")
local bxor = bit.bxor
local band = bit.band

local MenuState = {}
MenuState.__index = MenuState

local HISTORY_FILE = "seed_history.txt"
local HISTORY_LIMIT = 5

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function parseSeed(text)
    local t = trim(text or "")
    if t == "" then
        return 42
    end

    local n = tonumber(t)
    if n then
        n = math.floor(n)
        if n < 0 then n = -n end
        if n == 0 then n = 1 end
        return n
    end

    local h = 2166136261
    for i = 1, #t do
        h = band(bxor(h, string.byte(t, i)), 0xFFFFFFFF)
        h = band(h * 16777619, 0xFFFFFFFF)
    end
    h = band(h, 0x7FFFFFFF)
    if h == 0 then h = 1 end
    return h
end

local function loadSeedHistory()
    if not love.filesystem.getInfo(HISTORY_FILE) then
        return {}
    end
    local content = love.filesystem.read(HISTORY_FILE)
    if not content or content == "" then
        return {}
    end

    local out = {}
    for line in content:gmatch("[^\r\n]+") do
        out[#out + 1] = line
        if #out >= HISTORY_LIMIT then
            break
        end
    end
    return out
end

local function saveSeedHistory(history)
    local lines = {}
    for i = 1, math.min(#history, HISTORY_LIMIT) do
        lines[#lines + 1] = history[i]
    end
    love.filesystem.write(HISTORY_FILE, table.concat(lines, "\n"))
end

function MenuState.new(stateManager)
    return setmetatable({
        stateManager = stateManager,
        ui = UI.new(),
        seedInput = "42",
        seedHistory = {},
        resolvedSeed = 42,
    }, MenuState)
end

function MenuState:onEnter()
    Input3D.setCapture(false)
    love.mouse.setVisible(true)
    self.seedHistory = loadSeedHistory()
    if #self.seedHistory > 0 then
        self.seedInput = self.seedHistory[1]
    end
    self.ui:setText("seed_input", self.seedInput)
    self.resolvedSeed = parseSeed(self.seedInput)
end

function MenuState:_rememberSeed(seedText)
    local normalized = trim(seedText)
    if normalized == "" then
        normalized = tostring(self.resolvedSeed)
    end

    local nextHistory = { normalized }
    for _, v in ipairs(self.seedHistory) do
        if v ~= normalized then
            nextHistory[#nextHistory + 1] = v
        end
        if #nextHistory >= HISTORY_LIMIT then
            break
        end
    end

    self.seedHistory = nextHistory
    saveSeedHistory(self.seedHistory)
end

function MenuState:_startGame()
    self.seedInput = self.ui:getText("seed_input")
    self.resolvedSeed = parseSeed(self.seedInput)
    self:_rememberSeed(self.seedInput)
    self.stateManager:switch(GameState.PLAYING, {
        seed = self.resolvedSeed,
        resetWorld = true,
    })
end

function MenuState:update()
end

function MenuState:draw()
    self.ui:beginFrame()

    love.graphics.clear(0.04, 0.05, 0.07, 1)

    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local panelW = 580
    local panelH = 420
    local panelX = math.floor((sw - panelW) * 0.5)
    local panelY = math.floor((sh - panelH) * 0.5)

    self.ui:panel(panelX, panelY, panelW, panelH, "Terragen")

    love.graphics.setColor(1, 1, 1, 0.75)
    love.graphics.print("Procedural voxel sandbox", panelX + 16, panelY + 40)

    local inputX = panelX + 20
    local inputY = panelY + 96
    local inputW = panelW - 40
    local inputH = 40

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("World Seed (number or text):", inputX, inputY - 24)
    self.seedInput = self.ui:textInput("seed_input", inputX, inputY, inputW, inputH, self.seedInput, {
        placeholder = "e.g. 12345 or my_world",
        maxLen = 64,
    })

    self.resolvedSeed = parseSeed(self.seedInput)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print("Resolved Seed: " .. tostring(self.resolvedSeed), inputX, inputY + 52)

    local buttonY = panelY + 180
    local btnW = 170
    local gap = 14
    local rowW = btnW * 3 + gap * 2
    local rowX = panelX + math.floor((panelW - rowW) * 0.5)

    if self.ui:button("random_seed", "Random Seed", rowX, buttonY, btnW, 44) then
        local randomSeed = tostring(love.math.random(1, 2147483646))
        self.seedInput = randomSeed
        self.ui:setText("seed_input", randomSeed)
    end

    if self.ui:button("play", "Play", rowX + btnW + gap, buttonY, btnW, 44) then
        self:_startGame()
    end

    if self.ui:button("quit", "Quit", rowX + (btnW + gap) * 2, buttonY, btnW, 44) then
        love.event.quit()
    end

    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print("Recent Seeds:", inputX, panelY + 256)
    for i = 1, math.min(#self.seedHistory, HISTORY_LIMIT) do
        love.graphics.setColor(1, 1, 1, 0.72)
        love.graphics.print(string.format("%d. %s", i, self.seedHistory[i]), inputX, panelY + 256 + i * 20)
    end

    love.graphics.setColor(1, 1, 1, 0.55)
    love.graphics.print("Enter: Play    Esc: Quit", inputX, panelY + panelH - 30)

    self.ui:endFrame()
end

function MenuState:keypressed(key)
    if key == "return" or key == "kpenter" then
        self:_startGame()
        return
    end
    if key == "escape" then
        love.event.quit()
        return
    end
    self.ui:keypressed(key)
end

function MenuState:textinput(text)
    self.ui:textinput(text)
end

function MenuState:mousemoved(x, y)
    self.ui:mousemoved(x, y)
end

function MenuState:mousepressed(x, y, button)
    self.ui:mousepressed(x, y, button)
end

return MenuState
