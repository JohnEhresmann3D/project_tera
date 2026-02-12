local Pool = {}
Pool.free = {}

function Pool.acquire(size)
    local t = table.remove(Pool.free)
    if t then
        for i = 1, size do t[i] = 0 end
        -- Clear any extra entries beyond size
        for i = size + 1, #t do t[i] = nil end
        return t
    end
    t = {}
    for i = 1, size do t[i] = 0 end
    return t
end

function Pool.release(t)
    Pool.free[#Pool.free + 1] = t
end

return Pool
