local last_alerts = {}
local cooldown = 300 -- Increased to 5 mins for disk space; it's less urgent than heat

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

function conky_check_alert(device, tmp_file)
    local raw_content = read_file(tmp_file)
    if not raw_content or raw_content == "" then return "" end

    local clean_val = string.match(raw_content, "%d+") 
    local value = tonumber(clean_val)
    
    if not value then return "" end

    local current_time = os.time()
    local message = ""
    local threshold = 80 -- Default

    -- DISK SPACE LOGIC
    if device:find("Full") then
        threshold = 90
        if value >= threshold then
            if not last_alerts[device] or (current_time - last_alerts[device]) > cooldown then
                message = "System alert. Storage " .. device:gsub("_Full", "") .. " is almost full. " .. value .. " percent used."
                os.execute("espeak-ng -v en+f2 -s 140 '" .. message .. "' &")
                last_alerts[device] = current_time
            end
        end
    
    -- TEMPERATURE LOGIC (Original)
    else
        if value > 999 then value = math.floor(value / 1000) end
        
        if device == "GPU" then threshold = 80 end
        if device:find("Drive") or device == "NVMe" then threshold = 70 end

        if value >= threshold then
            if not last_alerts[device] or (current_time - last_alerts[device]) > cooldown then
                message = "System alert. " .. device .. " temperature critical. " .. value .. " degrees."
                os.execute("espeak-ng -v en+f2 -s 140 '" .. message .. "' &")
                last_alerts[device] = current_time
            end
        end
    end

    return ""
end
