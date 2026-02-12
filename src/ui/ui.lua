-- Tiny immediate-mode style UI helper used by menu/pause flows.
--
-- Mental model for learners:
-- 1) State calls `beginFrame()`.
-- 2) State draws widgets (`button`, `textInput`, ...).
-- 3) Widgets read mouse/keyboard state captured earlier this frame.
-- 4) State calls `endFrame()` to clear one-frame press flags.
local UI = {}
UI.__index = UI
local utf8 = require("utf8")

local function pointInRect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

function UI.new()
    return setmetatable({
        hotId = nil,
        activeId = nil,
        focusedInputId = nil,
        textInputs = {},
        mouseX = 0,
        mouseY = 0,
        pressed = false,
        clickedId = nil,
    }, UI)
end

function UI:beginFrame()
    -- Reset per-frame interaction state before drawing widgets.
    self.hotId = nil
    self.clickedId = nil
end

function UI:endFrame()
    self.pressed = false
end

function UI:mousemoved(x, y)
    self.mouseX = x
    self.mouseY = y
end

function UI:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end
    self.mouseX = x
    self.mouseY = y
    self.pressed = true
end

function UI:keypressed(key)
    -- UTF-8 safe backspace for focused text field.
    if key == "backspace" and self.focusedInputId then
        local entry = self.textInputs[self.focusedInputId]
        if entry then
            local byteoffset = utf8.offset(entry.value, -1)
            if byteoffset then
                entry.value = string.sub(entry.value, 1, byteoffset - 1)
            end
        end
    end
end

function UI:textinput(text)
    if not self.focusedInputId then
        return
    end
    local entry = self.textInputs[self.focusedInputId]
    if not entry then
        return
    end
    if #entry.value + #text > (entry.maxLen or 64) then
        return
    end
    entry.value = entry.value .. text
end

function UI:panel(x, y, w, h, title)
    love.graphics.setColor(0.08, 0.08, 0.1, 0.92)
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    love.graphics.setColor(1, 1, 1, 0.12)
    love.graphics.rectangle("line", x, y, w, h, 8, 8)
    if title and title ~= "" then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(title, x + 16, y + 12)
    end
end

function UI:button(id, label, x, y, w, h)
    -- "clicked" is emitted once on press while hovered.
    local hovered = pointInRect(self.mouseX, self.mouseY, x, y, w, h)
    if hovered then
        self.hotId = id
    end

    if self.pressed and hovered then
        self.activeId = id
    end

    local clicked = false
    if self.activeId == id and self.pressed then
        clicked = true
        self.clickedId = id
        self.activeId = nil
    end

    if hovered then
        love.graphics.setColor(0.2, 0.25, 0.32, 1)
    else
        love.graphics.setColor(0.14, 0.17, 0.22, 1)
    end
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(label, x, y + h * 0.5 - 7, w, "center")
    return clicked
end

function UI:textInput(id, x, y, w, h, value, opts)
    opts = opts or {}
    local entry = self.textInputs[id]
    if not entry then
        entry = { value = value or "", maxLen = opts.maxLen or 64 }
        self.textInputs[id] = entry
    elseif value ~= nil and value ~= entry.value then
        entry.value = value
    end

    local hovered = pointInRect(self.mouseX, self.mouseY, x, y, w, h)
    -- Click to focus; click elsewhere to blur.
    if self.pressed and hovered then
        self.focusedInputId = id
    elseif self.pressed and not hovered and self.focusedInputId == id then
        self.focusedInputId = nil
    end

    -- Render "focused" style if this field currently owns keyboard input.
    if self.focusedInputId == id then
        love.graphics.setColor(0.12, 0.14, 0.18, 1)
        love.graphics.rectangle("fill", x, y, w, h, 6, 6)
        love.graphics.setColor(0.45, 0.7, 1.0, 0.7)
        love.graphics.rectangle("line", x, y, w, h, 6, 6)
    else
        love.graphics.setColor(0.1, 0.12, 0.15, 1)
        love.graphics.rectangle("fill", x, y, w, h, 6, 6)
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.rectangle("line", x, y, w, h, 6, 6)
    end

    local text = entry.value
    if text == "" and opts.placeholder then
        love.graphics.setColor(1, 1, 1, 0.35)
        love.graphics.print(opts.placeholder, x + 10, y + h * 0.5 - 7)
    else
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(text, x + 10, y + h * 0.5 - 7)
    end

    return entry.value
end

function UI:getText(id)
    local entry = self.textInputs[id]
    return entry and entry.value or ""
end

function UI:setText(id, value)
    if not self.textInputs[id] then
        self.textInputs[id] = { value = value or "", maxLen = 64 }
    else
        self.textInputs[id].value = value or ""
    end
end

return UI
