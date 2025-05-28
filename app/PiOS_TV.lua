local w, h = term.getSize()
local apps = {}
local selected = 1
local scroll = 0
local description = ""
local version = "v5.0"
local contentStartY = 6
local dividerX = math.floor(w/2) + 1

-- Защита от минимальных размеров экрана
w = math.max(w, 20)
h = math.max(h, 10)

-- Автоподстройка кнопок
local buttonArea = {
    up = {x = math.max(1, w-3), y = math.max(1, h-3), symbol = "/\\"},
    down = {x = math.max(1, w-3), y = math.max(1, h-1), symbol = "\\/"},
    enter = {x = math.max(1, w-7), y = math.max(1, h-2), label = "[RUN]"}
}

local titleArt = {
    ".-.-. .-. .---.  .----. ",
    "| } }}{ |/ {-. \\{ {__-` ",
    "| |-' | }\\ '-} /.-._} } ",
    "`-'   `-' `---' `----'  "
}

local function safeWrite(text, x, y)
    if x >= 1 and x <= w and y >= 1 and y <= h then
        term.setCursorPos(x, y)
        term.write(text:sub(1, w - x + 1))
    end
end

local function drawUI()
    term.clear()
    
    -- Заголовок
    for i = 1, math.min(4, h) do
        safeWrite(titleArt[i] or "", 1, i)
    end
    
    -- Версия ОС
    safeWrite(version, w - #version + 1, 1)
    
    -- Горизонтальная линия
    safeWrite(string.rep("-", w), 1, 5)
    
    -- Вертикальная линия
    if w >= 20 then
        for y = 6, h do
            safeWrite("|", dividerX, y)
        end
    end
    
    -- Список приложений
    local maxVisible = math.max(0, h - 6)
    for i = 1, maxVisible do
        local appIndex = i + scroll
        if appIndex <= #apps then
            local prefix = appIndex == selected and "> " or "  "
            safeWrite(prefix..apps[appIndex], 1, 5 + i)
        end
    end
    
    -- Описание
    if w >= 20 then
        local lines = {}
        for line in description:gmatch("[^\n]+") do
            table.insert(lines, line)
        end
        for i = 1, math.min(#lines, maxVisible) do
            safeWrite(lines[i], dividerX + 2, 5 + i)
        end
    end
    
    -- Кнопки управления
    safeWrite(buttonArea.up.symbol, buttonArea.up.x, buttonArea.up.y)
    safeWrite(buttonArea.down.symbol, buttonArea.down.x, buttonArea.down.y)
    safeWrite(buttonArea.enter.label, buttonArea.enter.x, buttonArea.enter.y)
end

local function loadApps()
    apps = {}
    local files = fs.list("") or {}
    for _, file in pairs(files) do
        if not fs.isDir(file) and file:sub(-4) == ".lua" then
            table.insert(apps, file)
        end
    end
    table.sort(apps)
end

local function getDescription(appName)
    local metaFile = appName .. ".meta"
    if fs.exists(metaFile) then
        local f = fs.open(metaFile, "r")
        local content = f.readAll()
        f.close()
        return content:gsub("\r\n?", "\n")
    end
    return "No description available"
end

local function handleInput()
    while true do
        local event, btn, x, y = os.pullEvent("mouse_click")
        
        -- Проверка кнопки "Вверх"
        if x >= buttonArea.up.x and x <= buttonArea.up.x + 1 and y == buttonArea.up.y then
            if selected > 1 then selected = selected - 1 end
            
        -- Проверка кнопки "Вниз"
        elseif x >= buttonArea.down.x and x <= buttonArea.down.x + 1 and y == buttonArea.down.y then
            if selected < #apps then selected = selected + 1 end
            
        -- Проверка кнопки "Запуск"
        elseif x >= buttonArea.enter.x and x <= buttonArea.enter.x + 3 and y == buttonArea.enter.y then
            if #apps > 0 then
                local old = term.current()
                term.clear()
                shell.run(apps[selected])
                term.redirect(old)
            end
        end
        
        drawUI()
    end
end

local function main()
    while true do
        loadApps()
        if #apps == 0 then
            term.clear()
            safeWrite("No applications found!", 2, math.floor(h/2))
            safeWrite("Add .lua files to root", 2, math.floor(h/2)+1)
            sleep(3)
        else
            description = getDescription(apps[1])
            drawUI()
            handleInput()
        end
    end
end

pcall(main)