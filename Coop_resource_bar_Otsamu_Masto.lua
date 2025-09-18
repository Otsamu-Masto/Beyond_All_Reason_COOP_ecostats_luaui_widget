---@diagnostic disable: undefined-global
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Otsamu Masto Bar Extra",
		desc = "Adds a team resource display for tournament coop.",
		author = "OtsamuMasto",
		date = "2025",
		license = "GNU GPL, v2 or later",
		layer = -9999991,
		enabled = true,
	}
end


-- ______________________

--So the way it work in Spring is that a TeamID refer to one player, each player and their resoruce and units count as one team. In an 8v8 games, it is 16 teams with 2 alliance, not 2 teams with 16 players
--So what we need to do is iteratetively get the stat of all ally team and sum it up together
--
--

-- ______________________


-- Spring API
local spGetMyTeamID = Spring.GetMyTeamID
local spGetTeamResources = Spring.GetTeamResources

--local isSpectator = (myTeamID < 0) --check if player is currently spectator -- Masto

--local _, _, _, _, _, _, _, _, watchingTeamID = Spring.GetPlayerInfo(Spring.GetMyPlayerID())

--local spGetTeamResourcesUsage = Spring.GetTeamResourceUsage --Masto

-- UI
local font

-- State
local history_size
local metal_history
local energy_history
local smoothed_metal_balance
local smoothed_energy_balance

-- Math
local sformat = string.format
local math_floor = math.floor






--table to string

function recursiveTableToString(t, indent)
    indent = indent or ""
    local s = "{\n"
    local newIndent = indent .. "  "
    local first = true
    for k, v in pairs(t) do
        if not first then
            s = s .. ",\n"
        end
        s = s .. newIndent .. "[" .. tostring(k) .. "]="
        if type(v) == "table" then
            s = s .. recursiveTableToString(v, newIndent)
        elseif type(v) == "string" then
            s = s .. '"' .. v .. '"'
        else
            s = s .. tostring(v)
        end
        first = false
    end
    s = s .. "\n" .. indent .. "}"
    return s
end



local function short(n, f)
	if f == nil then f = 0 end
	local abs_n = math.abs(n)

	if abs_n > 999999 then
		return sformat("%+." .. f .. "fm", n / 1000000)
	elseif abs_n > 999 then
		return sformat("%+." .. f .. "fk", n / 1000)
	else
		return sformat("%+d", n)
	end
end

function widget:Initialize()
    if WG.fonts then
        font = WG.fonts.getFont(2)
    end

    history_size = 10 * (Game.gameSpeed or 30)
    metal_history = {}
    energy_history = {}
    smoothed_metal_balance = 0
    smoothed_energy_balance = 0
end

function widget:Update(dt)
    local myTeamID = spGetMyTeamID()
    if not myTeamID then return end

    -- Metal
    local _, _, m_pull, m_income = spGetTeamResources(myTeamID, 'metal')
    local m_balance = m_income - m_pull
    table.insert(metal_history, m_balance)
    if #metal_history > history_size then
        table.remove(metal_history, 1)

        local m_sum = 0
        for i = 1, #metal_history do
            m_sum = m_sum + metal_history[i]
        end
        if #metal_history > 0 then
            smoothed_metal_balance = m_sum / #metal_history
        end

        metal_history = {}
    end

    -- Energy
    local _, _, e_pull, e_income = spGetTeamResources(myTeamID, 'energy')
    local e_balance = e_income - e_pull
    table.insert(energy_history, e_balance)
    if #energy_history > history_size then
        table.remove(energy_history, 1)

        local e_sum = 0
        for i = 1, #energy_history do
            e_sum = e_sum + energy_history[i]
        end
        if #energy_history > 0 then
            smoothed_energy_balance = e_sum / #energy_history
        end

        energy_history = {}
    end
end






local function getAmountOfAllyTeams()
	local amountOfAllyTeams = 0
	for _, allyID in ipairs(Spring.GetAllyTeamList()) do
		if allyID ~= gaiaAllyID then
			amountOfAllyTeams = amountOfAllyTeams + 1
		end
	end
	return amountOfAllyTeams
end





--source:Masto

local function sumAllyTeamsResource()
    local myAllyTeamID = Spring.GetTeamAllyTeamID(Spring.GetMyTeamID())
    local teamID = Spring.GetMyTeamID()

    local combinedMetalIncome = 0
    local combinedEnergyIncome = 0
    local combinedMetalUsage = 0
    local combinedEnergyUsage = 0
    local combinedMetal = 0
    local combinedEnergy = 0

    -- Get a list of all teams in the game
    local allTeams = Spring.GetTeamList()

    -- Create a table to store the allied players (by playerID)
    local alliedPlayers = {}
    
    -- Iterate through all teams
    for _, teamID in ipairs(allTeams) do
        local allyTeamID = Spring.GetTeamAllyTeamID(teamID)
        
        -- Check if the team is an ally
        if allyTeamID == myAllyTeamID then
            -- Get the resource usage for this allied team
            local MetalCurrent,_,_,metalIncome,metalUsage,_,_,_,_   = Spring.GetTeamResources(teamID, 'metal')
            local EnergyCurrent,_,_,energyIncome,energyUsage,_,_,_,_   = Spring.GetTeamResources(teamID, 'energy')
            
             -- Add current stockpile to our combined totals
            combinedMetal = combinedMetal + MetalCurrent
            combinedEnergy = combinedEnergy + EnergyCurrent
            -- Add the income to our combined totals
            combinedMetalIncome = combinedMetalIncome + metalIncome
            combinedEnergyIncome = combinedEnergyIncome + energyIncome
            -- Add the usage to our combined totals
            combinedMetalUsage = combinedMetalUsage + metalUsage
            combinedEnergyUsage = combinedEnergyUsage + energyUsage        

        end
    end
    return {short(combinedMetal,1),short(combinedEnergy,1),short(combinedMetalIncome,1),short(combinedEnergyIncome,1),short(combinedMetalUsage,1),short(combinedEnergyUsage,1)}
end




-- 🎨 Helper function to draw rounded rectangle background
local function drawRoundedRect(x, y, width, height, radius, color)
    -- Set color with transparency
    gl.Color(color[1], color[2], color[3], color[4])
    
    -- For now, just draw a simple rectangle to avoid overlap issues
    -- The radius parameter is kept for future enhancement
    gl.Rect(x, y, x + width, y + height)
    
    -- Reset color
    gl.Color(1, 1, 1, 1)
end






function widget:DrawScreen()
    if not font then
        if WG.fonts then
            font = WG.fonts.getFont(2)
            if not font then return end
        else
            return
        end
    end

    -- Re-calculate bar positions since we cannot rely on WG.topbar
    local vsx, vsy = Spring.GetViewGeometry()
    local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)
    local orgHeight = 46
    local height = orgHeight * (1 + (ui_scale - 1) / 1.7)
    local widgetScale = (0.80 + (vsx * vsy / 6000000))
    local relXpos = 0.3
    local borderPadding = 5
    local xPos = math_floor(vsx * relXpos)
    local widgetSpaceMargin = 5 -- Default value from FlowUI

    local topbarArea = { math_floor(xPos + (borderPadding * widgetScale)), math_floor(vsy - (height * widgetScale)), vsx, vsy }
    local totalWidth = topbarArea[3] - topbarArea[1]
    local metal_width = math_floor(totalWidth / 4.4)
    local energy_width = metal_width

    local metalArea = { topbarArea[1], topbarArea[2], topbarArea[1] + metal_width, topbarArea[4] }
    local energy_x = topbarArea[1] + metal_width + widgetSpaceMargin
    local energyArea = { energy_x, topbarArea[2], energy_x + energy_width, topbarArea[4] }

    font:Begin()
    font:SetOutlineColor(0,0,0,1)

    -- Energy Balance
    local e_balance = smoothed_energy_balance
    local e_color
    if e_balance >= 0 then
        e_color = "\255\120\235\120" -- green
    else
        e_color = "\255\240\125\125" -- red
    end
    local e_barHeight = energyArea[4] - energyArea[2]
    local e_x = energyArea[1] + e_barHeight / 2
    local e_y = energyArea[2] + e_barHeight * 0.5
    font:Print(e_color .. short(e_balance, 1), e_x, e_y, 24, "co")

    -- Metal Balance
    local m_balance = smoothed_metal_balance
    local m_color
    if m_balance >= 0 then
        m_color = "\255\120\235\120" -- green
    else
        m_color = "\255\240\125\125" -- red
    end
    local m_barHeight = metalArea[4] - metalArea[2]
    local m_x = metalArea[1] + m_barHeight / 2
    local m_y = metalArea[2] + m_barHeight * 0.5
    font:Print(m_color .. short(m_balance, 1), m_x, m_y, 24, "co")





    --Draw bg
    -- Draw the rectangle
    drawRoundedRect(m_x+1000, m_y-700, 300, 600, 8, {0, 0, 0, 0.5})


    --Debug print

    --Spring.Echo("AmountOfAllyTeams")
    --Spring.Echo(getAmountOfAllyTeams())
    --Spring.Echo(Spring.GetAllyTeamList())
    --font:Print(m_color .. recursiveTableToString(Spring.GetTeamList(0)), m_x, m_y-50, 24, "co")
    --font:Print(m_color .. recursiveTableToString(Spring.GetTeamList(1)), e_x, e_y-50, 24, "co")
    --font:Print(m_color .. spGetMyTeamID(), e_x-100, e_y-100, 24, "co") --ID of selected player

    --Print fr

    local temporarytext = {"M","E","+M/s","+E/s","-M/s","-E/s"} --pls do better than this later
    font:Print(m_color .. recursiveTableToString(temporarytext), m_x, m_y-50, 24, "co")
    font:Print(m_color .. recursiveTableToString(sumAllyTeamsResource()), e_x, e_y-50, 24, "co")

    --better placement
    --font:Print(m_color .. recursiveTableToString(temporarytext), m_x+1050, m_y-100, 24, "co")
    --font:Print(m_color .. recursiveTableToString(sumAllyTeamsResource()), e_x+900, e_y-100, 24, "co")
    


    font:End()
end

