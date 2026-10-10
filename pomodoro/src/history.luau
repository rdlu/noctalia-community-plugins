-- Completed-stage log: one JSON object per line in <pluginDataDir>/history.jsonl,
-- e.g. {"ts":1791662400,"date":"2026-10-10","stage":"work","minutes":25,"session":2}.
-- Only stages that run out on their own are recorded; skips and resets are not.
-- `date` is the local day the stage finished on, so other tools can group by it.

local history = {}

local path = nil
local entries = {}

function history.init()
    local dir = noctalia.pluginDataDir()
    if dir == nil then
        return
    end
    path = dir .. "/history.jsonl"
    if not noctalia.fileExists(path) then
        return
    end
    local raw = noctalia.readFile(path)
    for line in string.gmatch(raw or "", "[^\n]+") do
        local entry = noctalia.json.decode(line)
        if type(entry) == "table" and type(entry.date) == "string" and type(entry.stage) == "string" then
            table.insert(entries, entry)
        end
    end
end

function history.record(stage: string, minutes: number, session: number)
    if path == nil then
        return
    end
    local ts = math.floor(noctalia.nowMs() / 1000)
    table.insert(entries, {
        ts = ts,
        date = noctalia.formatTime("%Y-%m-%d", ts),
        stage = stage,
        minutes = minutes,
        session = session,
    })
    -- No append in the API: rewrite the file. A year of pomodoros is a few
    -- thousand short lines.
    local lines = {}
    for _, entry in entries do
        local line = noctalia.json.encode(entry)
        if line ~= nil then
            table.insert(lines, line)
        end
    end
    noctalia.writeFile(path, table.concat(lines, "\n") .. "\n")
end

-- Work-stage totals per local date: { ["2026-10-10"] = { count = 6, minutes = 150 } }.
function history.daily()
    local out = {}
    for _, entry in entries do
        if entry.stage == "work" then
            local day = out[entry.date] or { count = 0, minutes = 0 }
            day.count += 1
            day.minutes += if type(entry.minutes) == "number" then entry.minutes else 0
            out[entry.date] = day
        end
    end
    return out
end

return history
