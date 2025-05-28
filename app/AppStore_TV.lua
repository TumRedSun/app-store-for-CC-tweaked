-- client.lua
-- GitHub App Store Client (Touch Only) v3.8

local VERSION = "3.8"
local selected = 1
local scroll = 0
local apps = {}

-- Области кнопок
local buttonAreas = {
    up = {x = 0, y = 0, w = 0, h = 0},
    down = {x = 0, y = 0, w = 0, h = 0},
    enter = {x = 0, y = 0, w = 0, h = 0},
    escape = {x = 0, y = 0, w = 0, h = 0}
}

-- Проверка попадания в область кнопки
local function checkButtonArea(x, y, area)
    return x >= area.x and x <= area.x + area.w - 1
       and y >= area.y and y <= area.y + area.h - 1
end

-- Текстовое перенос
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

-- Временное сообщение
local function showMessage(msg)
    local width = term.getSize()
    term.setCursorPos(1, 1)
    term.clearLine()
    term.write((" "..msg.." "):sub(1, width - 1))
    sleep(1)
    term.setCursorPos(1, 1)
    term.clearLine()
end

-- Удаление приложения
local function deleteApp(appName)
    local filesToDelete = {appName..".lua", appName..".meta"}
    for _, file in ipairs(filesToDelete) do
        if fs.exists(file) then fs.delete(file) end
    end
end

-- Отрисовка кнопок с новым расположением
local function drawButtons()
    local width, height = term.getSize()
    
    -- Новые координаты кнопок
    buttonAreas.up = {x = width - 5, y = height - 4, w = 3, h = 1}
    buttonAreas.enter = {x = width - 9, y = height - 3, w = 6, h = 1}
    buttonAreas.escape = {x = width - 3, y = height - 3, w = 3, h = 1}
    buttonAreas.down = {x = width - 5, y = height - 2, w = 3, h = 1}

    -- Отрисовка стрелок
    term.setCursorPos(buttonAreas.up.x, buttonAreas.up.y)
    term.write("/\\")
    term.setCursorPos(buttonAreas.down.x, buttonAreas.down.y)
    term.write("\\/")
    
    -- Отрисовка кнопок действий
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(buttonAreas.enter.x, buttonAreas.enter.y)
    term.write("[ OK ]")
    term.setCursorPos(buttonAreas.escape.x, buttonAreas.escape.y)
    term.write("[Q]")
    
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
end

-- Отрисовка интерфейса
local function drawMenu()
    term.clear()
    local width, height = term.getSize()
    local centerX = math.floor(width / 2)
    
    -- Заголовок
    term.setCursorPos(1, 1)
    term.write("App Store v"..VERSION)

    -- Разделитель
    for y = 2, height do
        term.setCursorPos(centerX, y)
        term.write("|")
    end

    -- Список приложений
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

    -- Описание
    if apps[selected] then
        local descLines = wrapText(apps[selected].description, width - centerX - 2)
        for i, line in ipairs(descLines) do
            if i > visibleLines then break end
            term.setCursorPos(centerX + 2, i + 1)
            term.write(line)
        end
    end
    
    drawButtons()
end

-- Обновление списка
local function updateAppList(serverId)
    rednet.send(serverId, "LIST")
    local _, response = rednet.receive(3)
    return response and response.apps or {}
end

-- Основная функция
local function main()
    rednet.open("back")
    local serverId
    local attempts = 0

    -- Поиск сервера
    repeat
        term.clear()
        term.setCursorPos(1, 1)
        print("Searching for server... (" .. attempts + 1 .. "/3)")
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

    while true do
        drawMenu()
        local event, param1, param2, param3 = os.pullEvent()

        -- Обработка сенсорных событий
        if event == "monitor_touch" or event == "mouse_click" then
            local x, y = param2, param3
            if checkButtonArea(x, y, buttonAreas.up) then
                selected = math.max(1, selected - 1)
                if selected - scroll < 1 then scroll = math.max(0, scroll - 1) end
            elseif checkButtonArea(x, y, buttonAreas.down) then
                selected = math.min(#apps, selected + 1)
                if selected - scroll > term.getSize() - 2 then scroll = scroll + 1 end
            elseif checkButtonArea(x, y, buttonAreas.enter) then
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
                        apps = updateAppList(serverId)
                    end
                end
            elseif checkButtonArea(x, y, buttonAreas.escape) then
                term.clear()
                term.setCursorPos(1, 1)
                return
            end
        elseif event == "timer" and param1 == timerId then
            apps = updateAppList(serverId)
            timerId = os.startTimer(5)
        end
    end
end

-- Инициализация
term.clear()
term.setCursorPos(1,1)
main()