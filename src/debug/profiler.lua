local Profiler = {}
Profiler.timings = {}

function Profiler.record(key, ms)
    local t = Profiler.timings[key]
    if not t then
        t = { total = 0, count = 0, max = 0, min = math.huge }
        Profiler.timings[key] = t
    end
    t.total = t.total + ms
    t.count = t.count + 1
    if ms > t.max then t.max = ms end
    if ms < t.min then t.min = ms end
end

function Profiler.getAverage(key)
    local t = Profiler.timings[key]
    if not t or t.count == 0 then return 0 end
    return t.total / t.count
end

function Profiler.reset()
    Profiler.timings = {}
end

function Profiler.draw(x, y)
    local count = 0
    for _ in pairs(Profiler.timings) do count = count + 1 end
    if count == 0 then return end

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x, y, 320, 20 * count + 10, 4)

    love.graphics.setColor(1, 1, 1, 1)
    local row = 0
    for key, t in pairs(Profiler.timings) do
        local avg = t.count > 0 and t.total / t.count or 0
        love.graphics.print(
            string.format("%s: avg=%.2fms max=%.2fms (n=%d)",
                key, avg, t.max, t.count),
            x + 6, y + 6 + row * 20
        )
        row = row + 1
    end
end

return Profiler
