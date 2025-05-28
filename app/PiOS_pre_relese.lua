local w, h = term.getSize()
local apps = {}
local selected = 1
local scroll = 0
local description = ""
local currentOS = fs.getName(shell.getRunningProgram())
local version = "v1.6.0"
local contentStartY = 6
local updateAvailable = false
local GITHUB_URL = "https://raw.githubusercontent.com/TumRedSun/app-store-for-CC-tweaked/main/app/PiOS.lua"
local CHECK_INTERVAL = 40

-- Защищённые системные приложения
local protectedApps = {
    ["app_store.lua"] = true,
    ["terminal.lua"] = true
}

local titleArt = {
    ".-.-. .-. .---.  .----. ",
    "| } }}{ |/ {-. \\{ {__-` ",
    "| |-' | }\\ '-} /.-._} } ",
    "`-'   `-' `---' `----'  "
}

-- Функции обновления
local function checkUpdate()
    while true do
        pcall(function()
            local response = http.get(GITHUB_URL)
            if response then
                local remoteSize = response.getResponseCode()
                local localSize = fs.getSize(currentOS)
                updateAvailable = remoteSize ~= localSize
            end
            if response then response.close() end
        end)
        sleep(CHECK_INTERVAL)
    end
end

local function installUpdate()
    term.clear()
    term.setCursorPos(1, 1)
    print("Downloading update...")
    
    local ok, err = pcall(function()
        local response = http.get(GITHUB_URL)
        if not response then error("Connection failed") end
        
        local data = response.readAll()
        response.close()
        
        local f = fs.open(currentOS, "w")
        f.write(data)
        f.close()
    end)
    
    if ok then
        print("Update complete! Restarting...")
        sleep(2)
        os.reboot()
    else
        print("Update failed: " .. (err or "unknown error"))
        sleep(2)
    end
end

-- Основные функции интерфейса
local function drawTitle()
    term.clear()
    for i, line in ipairs(titleArt) do
        term.setCursorPos(1, i)
        term.write(line)
    end
    term.setCursorPos(w - #version, 1)
    term.write(version)
    term.setCursorPos(1, #titleArt + 1)
    term.write(string.rep("-", w))
    contentStartY = #titleArt + 2
end

local function drawUI()
    drawTitle()
    
    local leftWidth = math.floor(w/2) - 2
    local rightStart = leftWidth + 3
    local maxVisible = h - contentStartY
    
    -- Список приложений
    for i = 1, maxVisible do
        local appIndex = i + scroll
        term.setCursorPos(1, contentStartY + i)
        if appIndex <= #apps then
            term.write(appIndex == selected and "> " .. apps[appIndex] or "  " .. apps[appIndex])
        end
    end
    
    -- Описание
    local lines = {}
    for line in description:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    for i = 1, math.min(#lines, maxVisible) do
        term.setCursorPos(rightStart, contentStartY + i)
        term.write(lines[i]:sub(1, w - rightStart) or "")
    end
    
    -- Разделители
    for y = contentStartY, h do
        term.setCursorPos(leftWidth + 1, y)
        term.write("|")
    end
    
    -- Индикаторы обновления
    if updateAvailable then
        term.setCursorPos(1, h)
        term.write("Update available! Press HOME")
    end
end

-- Функции управления приложениями
local function loadApps()
    local files = fs.list("")
    apps = {}
    
    for _, file in ipairs(files) do
        local isSystem = file == "startup.lua" or file == currentOS
        local isProtected = protectedApps[file]
        
        if not fs.isDir(file) 
           and not file:match("%.meta$") 
           and not isSystem
           and not isProtected then
            table.insert(apps, file)
        end
    end
    table.sort(apps)
    
    for app in pairs(protectedApps) do
        if fs.exists(app) and not fs.isDir(app) then
            table.insert(apps, 1, app)
        end
    end
end

local function getDescription(appName)
    local metaFile = appName .. ".meta"
    if fs.exists(metaFile) then
        local f = io.open(metaFile, "r")
        local content = f:read("*a")
        f:close()
        return content:gsub("\r\n?", "\n")
    end
    return "No description available"
end

local function deleteApp()
    if #apps == 0 then return end
    local appToDelete = apps[selected]
    
    if protectedApps[appToDelete] then
        term.clear()
        term.setCursorPos(1, 1)
        print("System app protected!")
        sleep(1)
        return
    end
    
    fs.delete(appToDelete)
    if fs.exists(appToDelete .. ".meta") then
        fs.delete(appToDelete .. ".meta")
    end
    
    loadApps()
    selected = math.max(1, math.min(selected, #apps))
    if #apps > 0 then
        description = getDescription(apps[selected])
    end
end

-- Новая система обработки ввода
local function handleInput()
    while true do
        local event, key = os.pullEvent()
        
        if event == "terminate" then
            return true
        end
        
        if event == "key" then
            if key == keys.up then
                if selected > 1 then
                    selected = selected - 1
                    if selected - scroll < 1 then scroll = scroll - 1 end
                end
            elseif key == keys.down then
                if selected < #apps then
                    selected = selected + 1
                    if selected - scroll > (h - contentStartY) then
                        scroll = math.min(scroll + 1, #apps - (h - contentStartY))
                    end
                end
            elseif key == keys.enter then
                term.clear()
                shell.run(apps[selected])
                drawUI()
            elseif key == keys.delete then
                deleteApp()
            elseif key == keys.home and updateAvailable then
                installUpdate()
            elseif key == keys.insert then
                os.queueEvent("terminate")
                return true
            end
        end
        
        if #apps > 0 then
            description = getDescription(apps[selected])
        end
        drawUI()
    end
end

-- Главная функция
local function main()
    loadApps()
    if #apps == 0 then
        term.clear()
        term.setCursorPos(1, 1)
        print("No applications found!")
        return
    end
    description = getDescription(apps[1])
    
    parallel.waitForAny(
        checkUpdate,
        function()
            while true do
                drawUI()
                if handleInput() then break end
                sleep(0)
            end
        end
    )
    
    -- Завершение работы
    term.clear()
    term.setCursorPos(1, 1)
end

-- Запуск с обработкой ошибок
pcall(main)