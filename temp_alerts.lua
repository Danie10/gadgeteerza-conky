local last_alerts = {}
local cooldown = 60 -- Seconds between voice alerts

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

    -- Use string.match safely
    local clean_temp = string.match(raw_content, "%d%d") 
    local temp = tonumber(clean_temp)
    
    -- Only print if we actually got a number to keep terminal clean
    if temp then
      --was for debugging  print("Corrected " .. device .. ": " .. tostring(temp))
    else
        return "" -- Exit quietly if file was temporarily unreadable
    end

    local threshold = 80 
    if device == "GPU" then threshold = 75 end
    if device:find("Drive") or device == "NVMe" then threshold = 60 end

    local current_time = os.time()
    
    if temp >= threshold then
        if not last_alerts[device] or (current_time - last_alerts[device]) > cooldown then
            local message = "System alert. " .. device .. " temperature critical. " .. temp .. " degrees."
            os.execute("espeak-ng -v en+f2 -s 140 '" .. message .. "' &")
            last_alerts[device] = current_time
        end
    end
    return ""
end
