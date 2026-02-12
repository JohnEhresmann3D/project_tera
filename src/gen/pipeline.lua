local Constants = require("src.constants")
local Hash = require("src.util.hash")

-- Worldgen pipeline orchestrator.
-- Each stage mutates chunk data in-place; stage index enables resumable
-- generation when running under a per-frame time budget.
local Pipeline = {}

-- Stages are registered in order
Pipeline.stages = {}

function Pipeline.registerStage(stage)
    Pipeline.stages[#Pipeline.stages + 1] = stage
end

-- Generate a chunk through all (or remaining) stages
-- Returns true if generation completed, false if interrupted by budget
function Pipeline.generate(chunk, worldSeed, budgetMs)
    -- Context object is the per-chunk "blackboard" shared by all stages.
    local ctx = {
        seed = worldSeed,
        cx = chunk.cx,
        cy = chunk.cy,
        chunk = chunk,
        -- Shared field caches (written by terrain stage, read by later stages).
        -- Stored on chunk between frames if generation is budget-interrupted.
        elevation = chunk._elevation or {},
        moisture = chunk._moisture or {},
        temperature = chunk._temperature or {},
    }

    local startTime = nil
    if budgetMs then
        startTime = love.timer.getTime()
    end

    for i = chunk.genStage + 1, #Pipeline.stages do
        local stage = Pipeline.stages[i]
        stage.run(ctx)
        chunk.genStage = i

        -- Persist fields so continuation next frame sees identical inputs.
        chunk._elevation = ctx.elevation
        chunk._moisture = ctx.moisture
        chunk._temperature = ctx.temperature

        if budgetMs and startTime then
            local elapsed = (love.timer.getTime() - startTime) * 1000
            if elapsed >= budgetMs and i < #Pipeline.stages then
                return false  -- budget exceeded, continue next frame
            end
        end
    end

    chunk.generated = true
    -- Clean up temporary field caches
    chunk._elevation = nil
    chunk._moisture = nil
    chunk._temperature = nil
    return true
end

function Pipeline.getStageCount()
    return #Pipeline.stages
end

return Pipeline
