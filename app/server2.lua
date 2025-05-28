-- server.lua
-- GitHub App Store Server v3.4

local SERVER_CHANNEL = 54321
local VERSION = "3.4"
local GITHUB_REPO = "https://api.github.com/repos/TumRedSun/app-store-for-CC-tweaked/contents/app"
local GITHUB_RAW = "https://raw.githubusercontent.com/TumRedSun/app-store-for-CC-tweaked/main/app/"
local UPDATE_INTERVAL = 5 -- Изменено с 30 на 5 секунд

local function setupNetwork()
    if not peripheral.find("modem") then
        error("Modem not connected!")
    end
    rednet.open("back")
end

local function getGitHubFiles()
    local response = http.get(GITHUB_REPO)
    if not response then return {} end
    
    local data = textutils.unserializeJSON(response.readAll())
    response.close()
    
    local files = {}
    for _, item in ipairs(data) do
        if item.type == "file" then
            table.insert(files, item.name)
        end
    end
    return files
end

local function downloadFile(filename)
    local content = http.get(GITHUB_RAW..filename).readAll()
    local file = fs.open(filename, "w")
    file.write(content)
    file.close()
    return true
end

local function updateFromGitHub()
    print("\nUpdating from GitHub...")
    local files = getGitHubFiles()
    
    for _, filename in ipairs(files) do
        if filename:match("%.lua$") or filename:match("%.meta$") then
            if pcall(downloadFile, filename) then
                print("Downloaded: "..filename)
            else
                print("Download failed: "..filename)
            end
        end
    end
end

-- Исправленная функция loadApps()
local function loadApps()
    local apps = {} -- Теперь это массив
    for _, filename in ipairs(fs.list("")) do
        if filename:match("%.lua$") and filename ~= "server.lua" then
            local appName = filename:gsub("%.lua$", "")
            local metaFile = appName..".meta"
            
            local meta = {}
            if fs.exists(metaFile) then
                local file = fs.open(metaFile, "r")
                meta = textutils.unserialize(file.readAll()) or {}
                file.close()
            end
            
            local file = fs.open(filename, "r")
            table.insert(apps, { -- Добавление в массив
                name = appName,
                filename = filename,
                code = file.readAll(),
                description = meta.description or "No description",
                version = meta.version or "1.0"
            })
            file.close()
        end
    end
    return apps
end

local function startServer()
    setupNetwork()
    print("Server v"..VERSION.." started")
    
    updateFromGitHub()
    
    parallel.waitForAny(function()
        while true do
            sleep(UPDATE_INTERVAL)
            pcall(updateFromGitHub) -- Обновление каждые 5 секунд
        end
    end, function()
        while true do
            local id, msg = rednet.receive()
            
            if msg == "PING" then
                rednet.send(id, "PONG")
                
            elseif msg == "LIST" then
                local apps = loadApps()
                rednet.send(id, {apps = apps}) -- Отправка массива
                
            elseif type(msg) == "table" and msg.download then
                local apps = loadApps()
                local app
                -- Поиск приложения по имени в массиве
                for _, a in ipairs(apps) do
                    if a.name == msg.download then
                        app = a
                        break
                    end
                end
                
                if app then
                    local files = {
                        {name = app.filename, content = app.code},
                        {name = app.name..".meta", 
                         content = textutils.serialize({
                            description = app.description,
                            version = app.version
                         })}
                    }
                    rednet.send(id, {files = files})
                end
            end
        end
    end)
end

pcall(startServer)
print("Server will reboot in 5 seconds...")
sleep(5)
os.reboot()