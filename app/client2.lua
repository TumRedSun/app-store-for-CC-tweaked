-- client.lua
-- GitHub App Store Client v3.6

local SERVER_CHANNEL = 54321
local VERSION = "3.6"
local selected = 1
local scroll = 0
local apps = {}

-- Text wrapping for descriptions
local function wrapText(text, width)
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        while #line > width do
            local space = line:sub(1, width):find(" [^ ]*$") or width
            table.insert(lines, line:sub(1, space))
            line = line:sub(space + 1)
        end
        table.insert(lines, line)
    end
    return lines
end

-- Temporary message display
local function showMessage(msg)
    local width = term.getSize()
    term.setCursorPos(1, 1)
    term.clearLine()
    term.write((" "..msg.." "):sub(1, width - 1))
    sleep(1)
    term.setCursorPos(1, 1)
    term.clearLine()
end

-- Delete an app
local function deleteApp(appName)
    local filesToDelete = {appName..".lua", appName..".meta"}
    for _, file in ipairs(filesToDelete) do
        if fs.exists(file) then fs.delete(file) end
    end
end

-- Draw UI
local function drawMenu()
    term.clear()
    local width, height = term.getSize()
    local centerX = math.floor(width / 2)
    
    -- Header
    term.setCursorPos(1, 1)
    term.write("App Store v"..VERSION)

    -- Vertical separator
    for y = 2, height do
        term.setCursorPos(centerX, y)
        term.write("|")
    end

    -- App list
    local visibleLines = height - 1
    for i = 1, visibleLines do
        local idx = i + scroll
        term.setCursorPos(1, i + 1)
        if apps[idx] then
            term.write(idx == selected and ">" or " ")
            local displayName = apps[idx].name.." v"..apps[idx].version
            term.write((" "..displayName):sub(1, centerX - 3))
        end
    end

    -- Description
    if apps[selected] then
        local descLines = wrapText(apps[selected].description, width - centerX - 2)
        for i, line in ipairs(descLines) do
            if i > visibleLines then break end
            term.setCursorPos(centerX + 2, i + 1)
            term.write(line)
        end
    end
end

-- Update app list
local function updateAppList(serverId)
    rednet.send(serverId, "LIST")
    local _, response = rednet.receive(3) -- 3-second timeout
    return response and response.apps or {}
end

local function main()
    rednet.open("back")
    local serverId
    local attempts = 0

    -- Server discovery with retries
    repeat
        term.clear()
        term.setCursorPos(1, 1)
        print("Searching for server... (" .. tostring(attempts + 1) .. "/3)")
        rednet.broadcast("PING")
        serverId = rednet.receive(3)
        attempts = attempts + 1
        if attempts >= 3 then
            showMessage("Server not found!")
            return
        end
    until serverId

    apps = updateAppList(serverId)
    local timerId = os.startTimer(5)

    -- Main loop
    while true do
        drawMenu()
        local event, param1, param2 = os.pullEvent()

        if event == "timer" and param1 == timerId then
            apps = updateAppList(serverId)
            timerId = os.startTimer(5)
        
        elseif event == "key" then
            local key = param1
            
            -- Navigation
            if key == keys.up then
                selected = math.max(1, selected - 1)
                if selected - scroll < 1 then scroll = math.max(0, scroll - 1) end
            
            elseif key == keys.down then
                selected = math.min(#apps, selected + 1)
                if selected - scroll > term.getSize() - 2 then scroll = scroll + 1 end
            
            -- Install
            elseif key == keys.enter then
                if apps[selected] then
                    rednet.send(serverId, {download = apps[selected].name})
                    local _, files = rednet.receive(5)
                    if files then
                        for _, file in ipairs(files.files) do
                            local f = fs.open(file.name, "w")
                            f.write(file.content)
                            f.close()
                        end
                        showMessage("Installed!")
                    end
                end
            
            -- Delete
            elseif key == keys.delete then
                if apps[selected] then
                    deleteApp(apps[selected].name)
                    apps = updateAppList(serverId)
                    showMessage("Deleted!")
                end
            
            -- Exit
            elseif key == keys.q then
                term.clear()
                term.setCursorPos(1, 1)
                return
            end
        end
    end
end

main()