local timeFontFamily = noctalia.loadFont("resources/JetBrainsMono-Regular.ttf")

local function formatTime(seconds, total)
  local showingHours = total >= 3600 or seconds >= 3600
  local hours = math.floor(seconds / 3600)
  local mins = math.floor((seconds % 3600) / 60)
  local secs = seconds % 60

  if showingHours then
    return string.format("%d:%02d:%02d", hours, mins, secs)
  else
    return string.format("%02d:%02d", mins, secs)
  end
end

local function formatMinutes(minutes)
    local hours = math.floor(minutes / 60)
    local mins = minutes % 60
    if hours == 0 then
        return string.format("%dm", mins)
    end
    return string.format("%dh %02dm", hours, mins)
end

local function dayKey(daysAgo)
    local now = math.floor(noctalia.nowMs() / 1000)
    return noctalia.formatTime("%Y-%m-%d", now - daysAgo * 86400)
end

-- Today's completed work sessions, then one bar per day for the last 7 days.
local function statsRow(daily)
    local today = daily[dayKey(0)] or { count = 0, minutes = 0 }
    local maxCount = 1
    for i = 0, 6 do
        local day = daily[dayKey(i)]
        if day and day.count > maxCount then
            maxCount = day.count
        end
    end
    local bars = {}
    for i = 6, 0, -1 do
        local key = dayKey(i)
        local count = if daily[key] then daily[key].count else 0
        table.insert(bars, ui.box({
            width = 6,
            height = 3 + math.floor(15 * count / maxCount),
            radius = 2,
            fill = if i == 0 then "primary" else "on_surface_variant",
        }))
    end
    return ui.row({ align = "center", gap = 8 }, {
        ui.label({
            text = noctalia.trp("stats.today", today.count, { time = formatMinutes(today.minutes) }),
            fontSize = 12,
            color = "on_surface_variant",
            flexGrow = 1,
        }),
        ui.row({ align = "end", gap = 3 }, bars),
    })
end

function onStartButtonClick()
    noctalia.state.set("pomodoro.nextCommand", "toggle")
end

function onSkipButtonClick()
    noctalia.state.set("pomodoro.nextCommand", "skip")
end

function onResetButtonClick()
    noctalia.state.set("pomodoro.nextCommand", "reset")
end

function onResetAllButtonClick()
    noctalia.state.set("pomodoro.nextCommand", "resetAll")
end

local function render(state, sessionData, daily)
    if not state or not state.sessionPtr or not sessionData then
        panel.render(
            ui.column({ flexGrow = 1, align = "center", justify = "center", gap = 8 }, {
                ui.glyph({ name = "brain", color = "primary" }),
                ui.label({
                    text = "Pomodoro",
                    fontSize = 18,
                    fontWeight = "bold",
                    color = "on_surface",
                }),
            })
        )
        return
    end

    local sessionNumber = state.sessionPtr.session
    local session = sessionData[sessionNumber]
    local stageNumber = state.sessionPtr.stage
    local stageTotalSeconds = session[stageNumber]

    local stageName =
        if stageNumber == 1 then
            noctalia.tr("work")
        else if sessionNumber < #sessionData then 
            noctalia.tr("short-break")
        else 
            noctalia.tr("long-break")

    local startButtonText =
        if state.isRunning then
            noctalia.tr("button.pause")
        else if state.secondsLeft > 0 and state.secondsLeft < stageTotalSeconds then
            noctalia.tr("button.resume")
        else
            noctalia.tr("button.start")

    local startButtonGlyph = if state.isRunning then "player-pause" else "player-play"

    local skipButtonEnabled = state.isDirty and (if state.isRunning then state.secondsLeft > 0 else stageTotalSeconds > 0)

    local resetButtonEnabled = state.isDirty and state.secondsLeft > 0

    local resetAllButtonEnabled = state.isDirty and (state.isRunning or state.secondsLeft > 0 or (state.sessionPtr.session > 1 and state.sessionPtr.stage > 1))

    local stageIcon = if state.sessionPtr.stage == 1 then "brain" else "coffee"

    panel.render(
        ui.column({ flexGrow = 1, gap = 16 }, {
            -- header
            ui.row({ align = "center", gap = 8 }, {
                ui.glyph({ name = stageIcon, color = "primary" }),

                ui.label({
                    text = "Pomodoro",
                    fontSize = 18,
                    fontWeight = "bold",
                    color = "on_surface",
                    flexGrow = 1,
                }),

                ui.label({
                    text = string.format("%s %d/%d", noctalia.tr("session"), sessionNumber, #sessionData),
                    fontSize = 12,
                    color = "on_surface_variant",
                }),
            }),

            -- time
            ui.column({ flexGrow = 1, align = "center", justify = "center", }, {
                ui.label({
                    text = stageName,
                    fontSize = 18,
                    fontWeight = "medium",
                    color = "primary",
                }),

                ui.label({
                    text = formatTime(state.secondsLeft, stageTotalSeconds),
                    fontSize = 42,
                    fontWeight = "bold",
                    fontFamily = timeFontFamily,
                    color = "primary",
                }),
            }),

            -- buttons
            ui.column({ gap = 8 }, {
                ui.row({ gap = 8 }, {
                    ui.button({
                        variant = "primary",
                        text = startButtonText,
                        glyph = startButtonGlyph,
                        onClick = "onStartButtonClick",
                        width = 157,
                        height = 35
                    }),

                    ui.button({
                        text = noctalia.tr("button.skip"),
                        glyph = "player-skip-forward",
                        onClick = "onSkipButtonClick",
                        enabled = skipButtonEnabled,
                        width = 157,
                        height = 35
                    }),
                }),

                ui.row({ gap = 8 }, {
                    ui.button({
                        text = noctalia.tr("button.reset"),
                        glyph = "refresh",
                        onClick = "onResetButtonClick",
                        enabled = resetButtonEnabled,
                        width = 157,
                        height = 35
                    }),

                    ui.button({
                        text = noctalia.tr("button.reset-all"),
                        glyph = "rotate",
                        onClick = "onResetAllButtonClick",
                        enabled = resetAllButtonEnabled,
                        width = 157,
                        height = 35
                    }),
                }),
            }),

            -- stats (only while track-history is on)
            if daily then statsRow(daily) else nil,
        }) -- column
    ) -- panel
end

local function refresh()
    local config = noctalia.state.get("pomodoro.config")
    local daily = if config and config.trackHistory then noctalia.state.get("pomodoro.history") or {} else nil
    render(noctalia.state.get("pomodoro.state"), noctalia.state.get("pomodoro.sessionData"), daily)
end

function onOpen(context)
    refresh()
end

--- main
noctalia.state.watch("pomodoro.state", function(state)
    refresh()
end)

noctalia.state.watch("pomodoro.sessionData", function(_sessionData)
    refresh()
end)

noctalia.state.watch("pomodoro.history", function(_daily)
    refresh()
end)

refresh()
