local hitpushPlayers = {}
local nohitPlayers = {}
local dmgmultPlayers = {}
local ridePairs = {}
local rideTasks = {}
local rideWaitingPlayers = {}
local noPickupPlayers = {}
local swingPlayers = {}
local swingTasks = {}
local infeatPlayers = {}
local freezecamPlayers = {}
local freezecamTasks = {}
local ghostPlacePlayers = {}
local flyingDropPlayers = {}
local reversehitPlayers = {}
local randomslotTasks = {}
local faketimeoutTasks = {}
local faketimeoutItems = {}
local soundbugTasks = {}
local buildPlayers = {}
local mistypePlayers = {}
local Attribute = luajava.bindClass('org.bukkit.attribute.Attribute')
local Material = luajava.bindClass('org.bukkit.Material')
local Vector = luajava.bindClass('org.bukkit.util.Vector')
local Particle = luajava.bindClass('org.bukkit.Particle')
local Sound = luajava.bindClass('org.bukkit.Sound')
local EntityType = luajava.bindClass('org.bukkit.entity.EntityType')
local crashParticle = nil
for _, n in ipairs({"EXPLOSION_EMITTER", "EXPLOSION_HUGE", "EXPLOSION_LARGE", "EXPLOSION"}) do
    local ok, p = pcall(function() return Particle[n] end)
    if ok and p then crashParticle = p; break end
end
local crashSound = nil
for _, n in ipairs({"ENTITY_LIGHTNING_BOLT_THUNDER", "ENTITY_LIGHTNING_THUNDER", "ENTITY_GENERIC_EXPLODE"}) do
    local ok, s = pcall(function() return Sound[n] end)
    if ok and s then crashSound = s; break end
end
local function isVersionAtLeast(maj, min, pat)
    local v = Bukkit:getBukkitVersion()
    local a, b, c = v:match("(%d+)%.(%d+)%.?(%d*)")
    a = tonumber(a) or 0; b = tonumber(b) or 0; c = tonumber(c) or 0
    return a > maj or (a == maj and (b > min or (b == min and c >= pat)))
end

local function getPlayers(target)
    if target == "*" then
        return Glacier.getOnlinePlayers(), true
    end
    local excluded = {}
    if target:sub(1, 2) == "*!" then
        local excludePart = target:sub(3)
        for nick in excludePart:gmatch("[^,]+") do
            excluded[nick:lower()] = true
        end
        local result = {}
        for _, p in ipairs(Glacier.getOnlinePlayers()) do
            if not excluded[p:getName():lower()] then
                result[#result + 1] = p
            end
        end
        return result, true
    end
    if target:find(",") then
        local result = {}
        local notFound = {}
        for nick in target:gmatch("[^,]+") do
            local p = Bukkit:getPlayer(nick)
            if p and p:isOnline() then
                result[#result + 1] = p
            else
                notFound[#notFound + 1] = nick
            end
        end
        if #result == 0 then
            return nil, false, "No players found for: " .. target
        end
        return result, false, nil, notFound
    end
    local targetPlayer = Bukkit:getPlayer(target)
    if not targetPlayer or not targetPlayer:isOnline() then
        return nil, false, "Player '" .. target .. "' not found or offline"
    end
    return {targetPlayer}, false
end
local commandInfos = {
    "hitpush <player> <upward_blocks> - Push victim in attacker direction (toggle)",
    "nohit <player> - Visual hits but no HP loss (toggle)",
    "dmgmult <player> <multiplier> <incoming|outgoing> - Damage multiplier (0 = off)",
    "noitempickup <player> - Items flee from player (toggle)",
    "ride <rider> [vehicle] - Make rider sit on vehicle player or mob (click mob to ride)",
    "drop <player> <one|all> - Drop item from player's main hand",
    "scale <player> <size> - Change player size (0.01-17, requires 1.20.5+)",
    "invshuffle <player> <hotbar|inventory|*> [seconds] - Shuffle hotbar, inventory only, or all (*), optionally for X seconds",
    "offhand <player> - Swap main hand and offhand items",
    "naked <player> - Strip armor and throw it forward",
    "creeperpanic <player> - Spawn a panic creeper visible mainly to target",
    "resourcepack <*|player> <url> - Force player(s) to load a resource pack from direct link",
    "swinghand <player> - Toggle continuous hand swing animation (toggle)",
    "reach <player> <blocks|entities|all> <value> - Set player reach (default: blocks=4.5, entities=3, requires 1.20.5+)",
    "gravity <player> <on|off|clear> [strength] - Toggle gravity or reset to default, optionally set strength (default: 0.08, requires 1.20.5+)",
    "freezecam <*|player> - Apply powder snow freeze effect to player(s) (toggle)",
    "infeat <*|player> - Toggle infinite eating animation, item never consumed (toggle)",
    "ghostplace <*|player> - Toggle ghost block placing (block placed then instantly removed)",
    "flyingitemdrops <*|player> - Toggle flying item drops (items shoot upward when dropped)",
    "reversehit <*|player> - Attacker gets damage instead of victim (toggle)",
    "randomslot <*|player> <seconds> - Change selected hotbar slot randomly every N seconds (toggle)",
    "faketimeout <*|player> - Simulate server timeout: freeze entities, drop items vanish, gravity off, kick after 8-15s (toggle)",
    "soundbug <*|player> - Stop all sounds for player every tick (toggle)",
    "build <*|player> - Bypass region protection and allow building/breaking anywhere (toggle)",
    "mistype <player> - Toggle random typos in commands (toggle)",
    "title <*|player> <title> [subtitle] - Send title/subtitle to player with color formatting",
    "crash <*|player> - Spam particles and sounds to crash player's client",
    "serverlag <seconds> - Freeze main server thread for N seconds (1-300)",
    "scripthelp - Show this help"
}

Glacier.registerEvent('EntityDamageByEntityEvent', function(event)
    local entity = event:getEntity()
    local damager = event:getDamager()
    if damager then
        local damagerName = damager:getName()
        if nohitPlayers[damagerName] then
            event:setDamage(0)
        end
        if dmgmultPlayers[damagerName] and dmgmultPlayers[damagerName].outgoing then
            local mult = dmgmultPlayers[damagerName].outgoing
            local damage = event:getDamage()
            event:setDamage(damage * mult)
        end
        if reversehitPlayers[damagerName] and entity and entity.getType then
            local dmg = event:getDamage()
            event:setDamage(0)
            delay(1, function()
                pcall(function()
                    damager:damage(dmg)
                end)
            end)
        end
        if hitpushPlayers[damagerName] and entity then
            local upwardBlocks = hitpushPlayers[damagerName]
            local loc = damager:getLocation()
            local dir = loc:getDirection()
            if dir then
                local yVel = math.sqrt(2 * 0.08 * upwardBlocks)
                local velocity = dir:clone()
                velocity:setY(yVel)
                delay(1, function()
                    entity:setVelocity(velocity)
                end)
            end
        end
    end
    if entity and entity:getName() then
        local victimName = entity:getName()
        if dmgmultPlayers[victimName] and dmgmultPlayers[victimName].incoming then
            local mult = dmgmultPlayers[victimName].incoming
            local damage = event:getDamage()
            event:setDamage(damage * mult)
        end
    end
end)

Command {
    name = 'hitpush',
    description = 'Toggle hitpush for a player with upward force'
} (function(user, args)
    if #args < 2 then
        user:sendMessage("&cUsage: hitpush <player> <upward_blocks>")
        return
    end
    local upwardBlocks = tonumber(args[2])
    if not upwardBlocks or upwardBlocks < 0 then
        user:sendMessage("&cInvalid upward_blocks value")
        return
    end
    local players, isAll, errorMsg = getPlayers(args[1])
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    local enabled, disabled = 0, 0
    for _, player in ipairs(players) do
        local playerName = player:getName()
        if hitpushPlayers[playerName] then
            hitpushPlayers[playerName] = nil
            disabled = disabled + 1
        else
            hitpushPlayers[playerName] = upwardBlocks
            enabled = enabled + 1
        end
    end
    if enabled > 0 then
        user:sendMessage("&aHitpush enabled for &f" .. enabled .. "&a player(s) (upward: &f" .. upwardBlocks .. "&a blocks)")
        log_info("Hitpush enabled for " .. enabled .. " player(s)")
    end
    if disabled > 0 then
        user:sendMessage("&cHitpush disabled for &f" .. disabled .. "&c player(s)")
        log_info("Hitpush disabled for " .. disabled .. " player(s)")
    end
end)

Command {
    name = 'nohit',
    description = 'Toggle nohit for a player (visual hit but no HP loss)'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: nohit <player>")
        return
    end
    local target = args[1]
    local players, isAll, errorMsg = getPlayers(target)
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    local enabled, disabled = 0, 0
    for _, player in ipairs(players) do
        local playerName = player:getName()
        if nohitPlayers[playerName] then
            nohitPlayers[playerName] = nil
            disabled = disabled + 1
        else
            nohitPlayers[playerName] = true
            enabled = enabled + 1
        end
    end
    if enabled > 0 then
        user:sendMessage("&aNohit enabled for &f" .. enabled .. "&a player(s)")
        log_info("Nohit enabled for " .. enabled .. " player(s)")
    end
    if disabled > 0 then
        user:sendMessage("&cNohit disabled for &f" .. disabled .. "&c player(s)")
        log_info("Nohit disabled for " .. disabled .. " player(s)")
    end
end)

Command {
    name = 'dmgmult',
    description = 'Toggle damage multiplier for a player (0 = disable)'
} (function(user, args)
    if #args < 3 then
        user:sendMessage("&cUsage: dmgmult <player> <multiplier> <incoming|outgoing>")
        return
    end
    local multiplier = tonumber(args[2])
    local dmgType = args[3]
    if multiplier == nil or multiplier < 0 then
        user:sendMessage("&cInvalid multiplier value")
        return
    end
    if dmgType ~= "incoming" and dmgType ~= "outgoing" then
        user:sendMessage("&cType must be 'incoming' or 'outgoing'")
        return
    end
    local players, isAll, errorMsg = getPlayers(args[1])
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    for _, player in ipairs(players) do
        local playerName = player:getName()
        if not dmgmultPlayers[playerName] then
            dmgmultPlayers[playerName] = {}
        end
        dmgmultPlayers[playerName][dmgType] = multiplier
    end
    local count = #players
    if multiplier == 0 then
        user:sendMessage("&cDamage &f" .. dmgType .. "&c multiplier disabled for &f" .. count .. "&c player(s)")
        log_info("Damage " .. dmgType .. " multiplier disabled for " .. count .. " player(s)")
    else
        user:sendMessage("&aDamage &f" .. dmgType .. "&a multiplier set to &f" .. multiplier .. "&a for &f" .. count .. "&a player(s)")
        log_info("Damage " .. dmgType .. " multiplier set to " .. multiplier .. " for " .. count .. " player(s)")
    end
end)

Glacier.registerEvent('PlayerAttemptPickupItemEvent', function(event)
    local player = event:getPlayer()
    local playerName = player:getName()
    if noPickupPlayers[playerName] then
        event:setCancelled(true)
        local item = event:getItem()
        if item and item:isValid() then
            local dir = player:getLocation():getDirection()
            local vel = item:getVelocity()
            vel:setX(dir:getX() * 0.5)
            vel:setY(0.2)
            vel:setZ(dir:getZ() * 0.5)
            item:setVelocity(vel)
        end
    end
end)

Command {
    name = 'noitempickup',
    description = 'Toggle item fleeing for a player'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: noitempickup <player>")
        return
    end
    local target = args[1]
    local players, isAll, errorMsg = getPlayers(target)
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    local enabled, disabled = 0, 0
    for _, player in ipairs(players) do
        local playerName = player:getName()
        if noPickupPlayers[playerName] then
            noPickupPlayers[playerName] = nil
            disabled = disabled + 1
        else
            noPickupPlayers[playerName] = true
            enabled = enabled + 1
        end
    end
    if enabled > 0 then
        user:sendMessage("&aNoItemPickup enabled for &f" .. enabled .. "&a player(s)")
        log_info("NoItemPickup enabled for " .. enabled .. " player(s)")
    end
    if disabled > 0 then
        user:sendMessage("&cNoItemPickup disabled for &f" .. disabled .. "&c player(s)")
        log_info("NoItemPickup disabled for " .. disabled .. " player(s)")
    end
end)

Command {
    name = 'ride',
    description = 'Make a player ride another player or mob'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: ride <rider> [vehicle] - If only rider given, right-click any mob to ride it")
        return
    end
    local riderName = args[1]
    local riderPlayer = Bukkit:getPlayer(riderName)
    if not riderPlayer or not riderPlayer:isOnline() then
        user:sendMessage("&cPlayer '" .. riderName .. "' not found or offline")
        return
    end
    if #args == 1 then
        if rideWaitingPlayers[riderName] then
            rideWaitingPlayers[riderName] = nil
            riderPlayer:sendMessage("&cRide mode cancelled")
            user:sendMessage("&cRide mode cancelled for &f" .. riderName)
            log_info("Ride mode cancelled for " .. riderName)
            return
        end
        local found = false
        for key, _ in pairs(ridePairs) do
            if key:find("|" .. riderName .. "$") then
                ridePairs[key] = nil
                if rideTasks[key] then
                    cancelTask(rideTasks[key])
                    rideTasks[key] = nil
                end
                found = true
            end
        end
        if found then
            riderPlayer:eject()
            riderPlayer:sendMessage("&cYou are no longer riding")
            user:sendMessage("&cRide cancelled for &f" .. riderName)
            log_info("Ride cancelled for " .. riderName)
        else
            rideWaitingPlayers[riderName] = true
            riderPlayer:sendMessage("&aRight-click any mob to start riding it!")
            user:sendMessage("&aRide mode enabled for &f" .. riderName .. "&a - right-click a mob")
            log_info("Ride mode enabled for " .. riderName)
        end
        return
    end
    local vehicleName = args[2]
    local vehiclePlayer = Bukkit:getPlayer(vehicleName)
    if not vehiclePlayer or not vehiclePlayer:isOnline() then
        user:sendMessage("&cPlayer '" .. vehicleName .. "' not found or offline")
        return
    end
    local key = vehicleName .. "|" .. riderName
    if ridePairs[key] then
        ridePairs[key] = nil
        if rideTasks[key] then
            cancelTask(rideTasks[key])
            rideTasks[key] = nil
        end
        vehiclePlayer:eject()
        user:sendMessage("&cRide disabled: &f" .. riderName .. "&c off &f" .. vehicleName)
        log_info("Ride disabled: " .. riderName .. " off " .. vehicleName)
    else
        ridePairs[key] = true
        rideTasks[key] = repeatTask(0, 1, function()
            if not ridePairs[key] then return end
            local v = Bukkit:getPlayer(vehicleName)
            local r = Bukkit:getPlayer(riderName)
            if not v or not v:isOnline() or not r or not r:isOnline() then
                ridePairs[key] = nil
                rideTasks[key] = nil
                return
            end
            local vehicle = r:getVehicle()
            if not r:isInsideVehicle() or not vehicle or vehicle:getEntityId() ~= v:getEntityId() then
                v:addPassenger(r)
            end
        end)
        user:sendMessage("&aRide enabled: &f" .. riderName .. "&a riding &f" .. vehicleName)
        log_info("Ride enabled: " .. riderName .. " riding " .. vehicleName)
    end
end)

Glacier.registerEvent('PlayerInteractEntityEvent', function(event)
    local player = event:getPlayer()
    local playerName = player:getName()
    if rideWaitingPlayers[playerName] then
        local entity = event:getRightClicked()
        if entity and tostring(entity:getType()) ~= "PLAYER" then
            rideWaitingPlayers[playerName] = nil
            local vehicleName = tostring(entity:getType())
            local key = vehicleName .. "|" .. playerName
            ridePairs[key] = true
            rideTasks[key] = repeatTask(0, 1, function()
                if not ridePairs[key] then return end
                local r = Bukkit:getPlayer(playerName)
                if not r or not r:isOnline() then
                    ridePairs[key] = nil
                    rideTasks[key] = nil
                    return
                end
                pcall(function()
                    if not r:isInsideVehicle() or not r:getVehicle() or r:getVehicle():getEntityId() ~= entity:getEntityId() then
                        entity:addPassenger(r)
                    end
                end)
            end)
            player:sendMessage("&aNow riding: &f" .. vehicleName)
            log_info(playerName .. " started riding " .. vehicleName)
        end
    end
end)

Glacier.registerEvent('PlayerCommandPreprocessEvent', function(event)
    local player = event:getPlayer()
    local playerName = player:getName()
    if mistypePlayers[playerName] then
        local message = event:getMessage()
        local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        local pos = math.random(1, #chars)
        local randomChar = chars:sub(pos, pos)
        local mistyped = "/" .. randomChar .. message:sub(2)
        event:setCancelled(true)
        Bukkit:broadcastMessage("<" .. player:getDisplayName() .. "> " .. mistyped)
    end
end)

Command {
    name = 'mistype',
    description = 'Toggle random typos in commands'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: mistype <player>")
        return
    end
    local target = args[1]
    local players, isAll, errorMsg = getPlayers(target)
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    local enabled, disabled = 0, 0
    for _, player in ipairs(players) do
        local playerName = player:getName()
        if mistypePlayers[playerName] then
            mistypePlayers[playerName] = nil
            disabled = disabled + 1
        else
            mistypePlayers[playerName] = true
            enabled = enabled + 1
        end
    end
    if enabled > 0 then
        user:sendMessage("&aMistype enabled for &f" .. enabled .. "&a player(s)")
        log_info("Mistype enabled for " .. enabled .. " player(s)")
    end
    if disabled > 0 then
        user:sendMessage("&cMistype disabled for &f" .. disabled .. "&c player(s)")
        log_info("Mistype disabled for " .. disabled .. " player(s)")
    end
end)

Command {
    name = 'drop',
    description = 'Drop item from player hand (one/all)'
} (function(user, args)
    if #args < 2 then
        user:sendMessage("&cUsage: drop <player> <one|all>")
        return
    end
    local dropType = args[2]
    if dropType ~= "one" and dropType ~= "all" then
        user:sendMessage("&cType must be 'one' or 'all'")
        return
    end
    local players, isAll, errorMsg = getPlayers(args[1])
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    local count = 0
    for _, targetPlayer in ipairs(players) do
        local inventory = targetPlayer:getInventory()
        local handItem = inventory:getItemInMainHand()
        if not handItem or handItem:getType():name() == "AIR" then
        else
            local world = targetPlayer:getWorld()
            local location = targetPlayer:getEyeLocation()
            local dir = targetPlayer:getLocation():getDirection()
            if dropType == "one" then
                local droppedItem = handItem:clone()
                droppedItem:setAmount(1)
                handItem:setAmount(handItem:getAmount() - 1)
                if handItem:getAmount() <= 0 then
                    inventory:setItemInMainHand(nil)
                end
                pcall(function() targetPlayer:swingMainHand() end)
                delay(0, function()
                    local dropped = world:dropItem(location, droppedItem)
                    dropped:setVelocity(dir:multiply(0.4))
                end)
            else
                local droppedItem = handItem:clone()
                inventory:setItemInMainHand(nil)
                pcall(function() targetPlayer:swingMainHand() end)
                delay(0, function()
                    local dropped = world:dropItem(location, droppedItem)
                    dropped:setVelocity(dir:multiply(0.4))
                end)
            end
            count = count + 1
        end
    end
    user:sendMessage("&aDropped &f" .. dropType .. "&a from &f" .. count .. "&a player(s)")
    log_info("Drop " .. dropType .. " for " .. count .. " player(s)")
end)

Command {
    name = 'scale',
    description = 'Set player scale/size (1.0 = normal)'
} (function(user, args)
    if #args < 2 then
        user:sendMessage("&cUsage: scale <player> <size>")
        return
    end
    local scale = tonumber(args[2])
    if not scale or scale < 0.01 or scale > 17 then
        user:sendMessage("&cInvalid size value (must be between 0.01 and 17)")
        return
    end
    if not isVersionAtLeast(1, 20, 5) then
        user:sendMessage("&cScale requires server version 1.20.5+")
        return
    end
    local players, isAll, errorMsg = getPlayers(args[1])
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    local count = 0
    for _, player in ipairs(players) do
        local attr = player:getAttribute(Attribute.GENERIC_SCALE)
        if attr then
            attr:setBaseValue(scale)
            count = count + 1
        end
    end
    user:sendMessage("&aScale set to &f" .. scale .. "&a for &f" .. count .. "&a player(s)")
    log_info("Scale set to " .. scale .. " for " .. count .. " player(s)")
end)

local function shufflePlayerInventory(player, mode)
    local inventory = player:getInventory()
    local slots = {}
    local minSlot = 0
    local maxSlot = 8
    
    if mode == "inventory" then
        minSlot = 9
        maxSlot = 35
    elseif mode == "*" then
        minSlot = 0
        maxSlot = 35
    end
    
    for i = minSlot, maxSlot do
        slots[i] = inventory:getItem(i)
    end
    for i = maxSlot, minSlot + 1, -1 do
        local j = math.random(minSlot, i)
        slots[i], slots[j] = slots[j], slots[i]
    end
    for i = minSlot, maxSlot do
        inventory:setItem(i, slots[i])
    end
end

Command {
    name = 'invshuffle',
    description = 'Shuffle player hotbar, inventory only, or both (optional duration)'
} (function(user, args)
    if #args < 2 then
        user:sendMessage("&cUsage: invshuffle <player> <hotbar|inventory|*> [seconds]")
        return
    end
    
    local mode = args[2]:lower()
    if mode == "taskbar" then mode = "hotbar" end
    if mode == "all" then mode = "*" end
    
    if mode ~= "hotbar" and mode ~= "inventory" and mode ~= "*" then
        user:sendMessage("&cMode must be 'hotbar', 'inventory', or '*'")
        return
    end

    local duration = tonumber(args[3]) or 0
    local players, isAll, errorMsg = getPlayers(args[1])
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    for _, player in ipairs(players) do
        local playerName = player:getName()
        if duration <= 0 then
            shufflePlayerInventory(player, mode)
        else
            local iterations = duration * 2
            local count = 0
            local taskId
            taskId = repeatTask(0, 10, function()
                local p = Bukkit:getPlayer(playerName)
                if not p or not p:isOnline() then
                    cancelTask(taskId)
                    return
                end
                count = count + 1
                if count >= iterations then
                    cancelTask(taskId)
                    return
                end
                shufflePlayerInventory(p, mode)
            end)
        end
    end
    local count = #players
    local displayMode = mode == "*" and "All" or mode:gsub("^%l", string.upper)
    if duration <= 0 then
        user:sendMessage("&a" .. displayMode .. " shuffled for &f" .. count .. "&a player(s)")
        log_info(displayMode .. " shuffled for " .. count .. " player(s)")
    else
        user:sendMessage("&aInvshuffle (" .. displayMode:lower() .. ") started for &f" .. count .. "&a player(s) for &f" .. duration .. "&a seconds")
        log_info("Invshuffle (" .. displayMode:lower() .. ") started for " .. count .. " player(s) for " .. duration .. " seconds")
    end
end)

Command {
    name = 'offhand',
    description = 'Swap main hand and offhand items'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: offhand <player>")
        return
    end
    local target = args[1]
    local players, isAll, errorMsg = getPlayers(target)
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    for _, player in ipairs(players) do
        local inventory = player:getInventory()
        local mainItem = inventory:getItemInMainHand()
        local offItem = inventory:getItemInOffHand()
        inventory:setItemInMainHand(offItem)
        inventory:setItemInOffHand(mainItem)
    end
    if isAll then
        user:sendMessage("&aSwapped hands for all players")
        log_info("Swapped hands for all players")
    else
        user:sendMessage("&aSwapped hands for &f" .. players[1]:getName())
        log_info("Swapped hands for " .. players[1]:getName())
    end
end)

Command {
    name = 'naked',
    description = 'Strip armor from a player and drop it'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: naked <player>")
        return
    end
    local target = args[1]
    local players, isAll, errorMsg = getPlayers(target)
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    for _, player in ipairs(players) do
        local inventory = player:getInventory()
        local world = player:getWorld()
        local frozenLoc = player:getLocation()
        local dir = frozenLoc:getDirection()
        local armorSlots = {
            inventory:getHelmet(),
            inventory:getChestplate(),
            inventory:getLeggings(),
            inventory:getBoots()
        }
        inventory:setHelmet(nil)
        inventory:setChestplate(nil)
        inventory:setLeggings(nil)
        inventory:setBoots(nil)
        local freezeCount = 0
        local freezeTask
        local playerName = player:getName()
        freezeTask = repeatTask(0, 1, function()
            local p = Bukkit:getPlayer(playerName)
            if not p or not p:isOnline() or freezeCount >= 40 then
                cancelTask(freezeTask)
                return
            end
            local curLoc = p:getLocation()
            frozenLoc:setY(curLoc:getY())
            frozenLoc:setPitch(curLoc:getPitch())
            frozenLoc:setYaw(curLoc:getYaw())
            p:teleport(frozenLoc)
            freezeCount = freezeCount + 1
        end)
        local dropLoc = player:getEyeLocation()
        for i, item in ipairs(armorSlots) do
            if item and item:getType():name() ~= "AIR" then
                local delayTicks = i * 4
                local captured = item
                delay(delayTicks, function()
                    local dropped = world:dropItem(dropLoc, captured)
                    dropped:setVelocity(dir:clone():multiply(0.4))
                end)
            end
        end
    end
    if isAll then
        user:sendMessage("&aStripped armor from all players")
        log_info("Stripped armor from all players")
    else
        user:sendMessage("&aStripped armor from &f" .. players[1]:getName())
        log_info("Stripped armor from " .. players[1]:getName())
    end
end)

Command {
    name = 'creeperpanic',
    description = 'Spawn a panic creeper visible mainly to target'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: creeperpanic <player>")
        return
    end
    local target = args[1]
    local players, isAll, errorMsg = getPlayers(target)
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    for _, targetPlayer in ipairs(players) do
        local world = targetPlayer:getWorld()
        local loc = targetPlayer:getLocation()
        local dir = loc:getDirection()
        local spawnLoc = loc:clone()
        spawnLoc:setX(spawnLoc:getX() - dir:getX() * 2)
        spawnLoc:setZ(spawnLoc:getZ() - dir:getZ() * 2)
        delay(0, function()
            local creeper = world:spawnEntity(spawnLoc, EntityType.CREEPER)
            pcall(function() creeper:setAI(false) end)
            pcall(function() creeper:setSilent(true) end)
            pcall(function() creeper:setInvulnerable(true) end)
            pcall(function() targetPlayer:playSound(targetPlayer:getLocation(), Sound.ENTITY_CREEPER_PRIMED, 1.0, 1.0) end)
            local plugin = nil
            pcall(function() plugin = Glacier.getInstance() end)
            if plugin then
                for _, player in ipairs(Glacier.getOnlinePlayers()) do
                    if player:getName() ~= targetPlayer:getName() then
                        pcall(function() player:hideEntity(plugin, creeper) end)
                    end
                end
            end
            delay(28, function()
                if creeper and creeper:isValid() then
                    pcall(function() creeper:remove() end)
                end
            end)
        end)
    end
    if isAll then
        user:sendMessage("&aCreeper panic sent to all players")
        log_info("Creeper panic sent to all players")
    else
        user:sendMessage("&aCreeper panic sent to &f" .. players[1]:getName())
        log_info("Creeper panic sent to " .. players[1]:getName())
    end
end)

Command {
    name = 'freezecam',
    description = 'Apply powder snow freeze visual effect to player(s) (toggle)'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: freezecam <*|player>")
        return
    end
    local target = args[1]
    local players, isAll, errorMsg = getPlayers(target)
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    local frozen, unfrozen = 0, 0
    for _, player in ipairs(players) do
        local playerName = player:getName()
        if freezecamPlayers[playerName] then
            freezecamPlayers[playerName] = nil
            if freezecamTasks[playerName] then
                cancelTask(freezecamTasks[playerName])
                freezecamTasks[playerName] = nil
            end
            player:setFreezeTicks(0)
            unfrozen = unfrozen + 1
        else
            freezecamPlayers[playerName] = true
            player:setFreezeTicks(2147483647)
            freezecamTasks[playerName] = repeatTask(0, 10, function()
                local p = Bukkit:getPlayer(playerName)
                if not p or not p:isOnline() or not freezecamPlayers[playerName] then
                    freezecamPlayers[playerName] = nil
                    freezecamTasks[playerName] = nil
                    return
                end
                p:setFreezeTicks(2147483647)
            end)
            frozen = frozen + 1
        end
    end
    if frozen > 0 then
        user:sendMessage("&aFreezecam enabled for &f" .. frozen .. "&a player(s)")
        log_info("Freezecam enabled for " .. frozen .. " player(s)")
    end
    if unfrozen > 0 then
        user:sendMessage("&cFreezecam disabled for &f" .. unfrozen .. "&c player(s)")
        log_info("Freezecam disabled for " .. unfrozen .. " player(s)")
    end
end)

Command {
    name = 'gravity',
    description = 'Toggle gravity for a player, optionally set strength (1.20.5+)'
} (function(user, args)
    if #args < 2 then
        user:sendMessage("&cUsage: gravity <player> <on|off|clear> [strength]")
        return
    end
    local state = args[2]
    local strength = tonumber(args[3])
    if state ~= "on" and state ~= "off" and state ~= "clear" then
        user:sendMessage("&cState must be 'on', 'off' or 'clear'")
        return
    end
    local players, isAll, errorMsg = getPlayers(args[1])
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    local count = #players
    for _, targetPlayer in ipairs(players) do
        if state == "clear" then
            targetPlayer:setGravity(true)
            local gravAttr = targetPlayer:getAttribute(Attribute.GENERIC_GRAVITY)
            if gravAttr then gravAttr:setBaseValue(0.08) end
        elseif state == "off" then
            targetPlayer:setGravity(false)
        else
            targetPlayer:setGravity(true)
            if strength ~= nil and isVersionAtLeast(1, 20, 5) then
                local gravAttr = targetPlayer:getAttribute(Attribute.GENERIC_GRAVITY)
                if gravAttr then gravAttr:setBaseValue(strength) end
            end
        end
    end
    if state == "clear" then
        user:sendMessage("&aGravity reset for &f" .. count .. "&a player(s)")
        log_info("Gravity reset for " .. count .. " player(s)")
    elseif state == "off" then
        user:sendMessage("&aGravity disabled for &f" .. count .. "&a player(s)")
        log_info("Gravity disabled for " .. count .. " player(s)")
    else
        local msg = "&aGravity enabled for &f" .. count .. "&a player(s)"
        if strength ~= nil then msg = msg .. " &a(strength: &f" .. strength .. "&a)" end
        user:sendMessage(msg)
        log_info("Gravity enabled for " .. count .. " player(s)")
    end
end)

Command {
    name = 'reach',
    description = 'Set player reach for block and/or entity interaction (requires 1.20.5+)'
} (function(user, args)
    if #args < 3 then
        user:sendMessage("&cUsage: reach <player> <blocks|entities|all> <value>")
        return
    end
    local reachType = args[2]
    local reach = tonumber(args[3])
    if reachType ~= "blocks" and reachType ~= "entities" and reachType ~= "all" then
        user:sendMessage("&cType must be 'blocks', 'entities' or 'all'")
        return
    end
    if not reach or reach < 0 or reach > 64 then
        user:sendMessage("&cInvalid reach value (0-64)")
        return
    end
    if not isVersionAtLeast(1, 20, 5) then
        user:sendMessage("&cReach requires server version 1.20.5+")
        return
    end
    local players, isAll, errorMsg = getPlayers(args[1])
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    local count = 0
    for _, targetPlayer in ipairs(players) do
        if reachType == "blocks" or reachType == "all" then
            local blockAttr = targetPlayer:getAttribute(Attribute.PLAYER_BLOCK_INTERACTION_RANGE)
            if blockAttr then blockAttr:setBaseValue(reach) end
        end
        if reachType == "entities" or reachType == "all" then
            local entityAttr = targetPlayer:getAttribute(Attribute.PLAYER_ENTITY_INTERACTION_RANGE)
            if entityAttr then entityAttr:setBaseValue(reach) end
        end
        count = count + 1
    end
    user:sendMessage("&aReach (&f" .. reachType .. "&a) set to &f" .. reach .. " blocks&a for &f" .. count .. "&a player(s)")
    log_info("Reach (" .. reachType .. ") set to " .. reach .. " for " .. count .. " player(s)")
end)

Command {
    name = 'swinghand',
    description = 'Toggle continuous hand swing animation for a player'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: swinghand <player>")
        return
    end
    local target = args[1]
    local players, isAll, errorMsg = getPlayers(target)
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    local enabled, disabled = 0, 0
    for _, player in ipairs(players) do
        local playerName = player:getName()
        if swingPlayers[playerName] then
            swingPlayers[playerName] = nil
            if swingTasks[playerName] then
                cancelTask(swingTasks[playerName])
                swingTasks[playerName] = nil
            end
            disabled = disabled + 1
        else
            swingPlayers[playerName] = true
            swingTasks[playerName] = repeatTask(0, 1, function()
                local p = Bukkit:getPlayer(playerName)
                if not p or not p:isOnline() or not swingPlayers[playerName] then
                    swingPlayers[playerName] = nil
                    swingTasks[playerName] = nil
                    return
                end
                pcall(function() p:swingMainHand() end)
            end)
            enabled = enabled + 1
        end
    end
    if enabled > 0 then
        user:sendMessage("&aSwinghand enabled for &f" .. enabled .. "&a player(s)")
        log_info("Swinghand enabled for " .. enabled .. " player(s)")
    end
    if disabled > 0 then
        user:sendMessage("&cSwinghand disabled for &f" .. disabled .. "&c player(s)")
        log_info("Swinghand disabled for " .. disabled .. " player(s)")
    end
end)

Command {
    name = 'resourcepack',
    description = 'Force player(s) to load a resource pack from a direct URL'
} (function(user, args)
    if #args < 2 then
        user:sendMessage("&cUsage: resourcepack <*|player> <direct_url>")
        return
    end
    local target = args[1]
    local url = args[2]
    if not url:match("^https?://") then
        user:sendMessage("&cURL must start with http:// or https://")
        return
    end
    local players, isAll, errorMsg = getPlayers(target)
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    local count = 0
    for _, player in ipairs(players) do
        pcall(function()
            player:setResourcePack(url)
            count = count + 1
        end)
    end
    if isAll then
        user:sendMessage("&aResource pack sent to &f" .. count .. "&a player(s): &7" .. url)
        log_info("Resource pack forced for " .. count .. " player(s): " .. url)
    else
        user:sendMessage("&aResource pack sent to &f" .. players[1]:getName() .. "&a: &7" .. url)
        log_info("Resource pack forced for " .. players[1]:getName() .. ": " .. url)
    end
end)

Glacier.registerEvent('PlayerItemConsumeEvent', function(event)
    local player = event:getPlayer()
    if not infeatPlayers[player:getName()] then return end
    event:setCancelled(true)
end)

Command {
    name = 'infeat',
    description = 'Toggle infinite eating animation, item never consumed (toggle)'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: infeat <*|player>")
        return
    end
    local target = args[1]
    local players, isAll, errorMsg = getPlayers(target)
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    local enabled, disabled = 0, 0
    for _, player in ipairs(players) do
        local playerName = player:getName()
        if infeatPlayers[playerName] then
            infeatPlayers[playerName] = nil
            disabled = disabled + 1
        else
            infeatPlayers[playerName] = true
            enabled = enabled + 1
        end
    end
    if enabled > 0 then
        user:sendMessage("&aInfeat enabled for &f" .. enabled .. "&a player(s)")
        log_info("Infeat enabled for " .. enabled .. " player(s)")
    end
    if disabled > 0 then
        user:sendMessage("&cInfeat disabled for &f" .. disabled .. "&c player(s)")
        log_info("Infeat disabled for " .. disabled .. " player(s)")
    end
end)

Glacier.registerEvent('BlockPlaceEvent', function(event)
    local player = event:getPlayer()
    local playerName = player:getName()
    if ghostPlacePlayers[playerName] then
        event:setCancelled(true)
        delay(0, function()
            local block = event:getBlock()
            if block then block:setType(Material.AIR) end
        end)
    elseif buildPlayers[playerName] then
        event:setCancelled(false)
    end
end)

Command {
    name = 'ghostplace',
    description = 'Toggle ghost block placing (block placed then instantly removed)'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: ghostplace <*|player>")
        return
    end
    local target = args[1]
    local players, isAll, errorMsg = getPlayers(target)
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    local enabled, disabled = 0, 0
    for _, player in ipairs(players) do
        local playerName = player:getName()
        if ghostPlacePlayers[playerName] then
            ghostPlacePlayers[playerName] = nil
            disabled = disabled + 1
        else
            ghostPlacePlayers[playerName] = true
            enabled = enabled + 1
        end
    end
    if enabled > 0 then
        user:sendMessage("&aGhostplace enabled for &f" .. enabled .. "&a player(s)")
        log_info("Ghostplace enabled for " .. enabled .. " player(s)")
    end
    if disabled > 0 then
        user:sendMessage("&cGhostplace disabled for &f" .. disabled .. "&c player(s)")
        log_info("Ghostplace disabled for " .. disabled .. " player(s)")
    end
end)

Glacier.registerEvent('BlockBreakEvent', function(event)
    local player = event:getPlayer()
    if buildPlayers[player:getName()] then
        event:setCancelled(false)
    end
end)

Glacier.registerEvent('PlayerDropItemEvent', function(event)
    local player = event:getPlayer()
    local pName = player:getName()
    local item = event:getItemDrop()
    if faketimeoutTasks[pName] then
        delay(1, function()
            pcall(function()
                if item and item:isValid() then
                    local stack = item:getItemStack()
                    item:remove()
                    if not faketimeoutItems[pName] then faketimeoutItems[pName] = {} end
                    table.insert(faketimeoutItems[pName], stack)
                end
            end)
        end)
        return
    end
    if flyingDropPlayers[pName] then
        delay(1, function()
            if not item or not item:isValid() then return end
            item:setPickupDelay(32767)
            local taskId
            taskId = repeatTask(0, 1, function()
                if not item or not item:isValid() then
                    cancelTask(taskId)
                    return
                end
                local vel = item:getVelocity()
                vel:setX(vel:getX() * 0.85)
                vel:setY(0.12)
                vel:setZ(vel:getZ() * 0.85)
                item:setVelocity(vel)
            end)
        end)
    end
end)

Command {
    name = 'flyingitemdrops',
    description = 'Toggle flying item drops (items shoot upward when dropped)'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: flyingitemdrops <*|player>")
        return
    end
    local target = args[1]
    local players, isAll, errorMsg = getPlayers(target)
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    local enabled, disabled = 0, 0
    for _, player in ipairs(players) do
        local playerName = player:getName()
        if flyingDropPlayers[playerName] then
            flyingDropPlayers[playerName] = nil
            disabled = disabled + 1
        else
            flyingDropPlayers[playerName] = true
            enabled = enabled + 1
        end
    end
    if enabled > 0 then
        user:sendMessage("&aFlyingitemdrops enabled for &f" .. enabled .. "&a player(s)")
        log_info("Flyingitemdrops enabled for " .. enabled .. " player(s)")
    end
    if disabled > 0 then
        user:sendMessage("&cFlyingitemdrops disabled for &f" .. disabled .. "&c player(s)")
        log_info("Flyingitemdrops disabled for " .. disabled .. " player(s)")
    end
end)

Command {
    name = 'build',
    description = 'Bypass region protection and allow building/breaking anywhere (toggle)'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: build <*|player>")
        return
    end
    local target = args[1]
    local players, isAll, errorMsg = getPlayers(target)
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    local enabled, disabled = 0, 0
    for _, player in ipairs(players) do
        local playerName = player:getName()
        if buildPlayers[playerName] then
            buildPlayers[playerName] = nil
            disabled = disabled + 1
        else
            buildPlayers[playerName] = true
            enabled = enabled + 1
        end
    end
    if enabled > 0 then
        user:sendMessage("&aBuild enabled for &f" .. enabled .. "&a player(s)")
        log_info("Build enabled for " .. enabled .. " player(s)")
    end
    if disabled > 0 then
        user:sendMessage("&cBuild disabled for &f" .. disabled .. "&c player(s)")
        log_info("Build disabled for " .. disabled .. " player(s)")
    end
end)

Command {
    name = 'title',
    description = 'Send title/subtitle to player with color formatting'
} (function(user, args)
    if #args < 2 then
        user:sendMessage("&cUsage: title <*|player> <title> [subtitle]")
        return
    end
    local target = args[1]
    local title = args[2]:gsub("&", "§")
    local subtitle = ""
    if #args > 2 then
        subtitle = table.concat(args, " ", 3):gsub("&", "§")
    end
    local players, isAll, errorMsg = getPlayers(target)
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    for _, player in ipairs(players) do
        pcall(function()
            player:sendTitle(title, subtitle, 10, 70, 20)
        end)
    end
    if isAll then
        user:sendMessage("&aTitle sent to all players")
        log_info("Title sent to all players")
    else
        user:sendMessage("&aTitle sent to &f" .. players[1]:getName())
        log_info("Title sent to " .. players[1]:getName())
    end
end)


Command {
    name = 'soundbug',
    description = 'Stop all sounds for player every tick'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: soundbug <*|player>")
        return
    end
    local target = args[1]
    local players, isAll, errorMsg = getPlayers(target)
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    local enabled, disabled = 0, 0
    for _, player in ipairs(players) do
        local playerName = player:getName()
        if soundbugTasks[playerName] then
            cancelTask(soundbugTasks[playerName])
            soundbugTasks[playerName] = nil
            disabled = disabled + 1
        else
            local taskId
            taskId = repeatTask(0, 1, function()
                local p = Bukkit:getPlayer(playerName)
                if not p or not p:isOnline() then
                    cancelTask(taskId)
                    soundbugTasks[playerName] = nil
                    return
                end
                pcall(function() p:stopAllSounds() end)
            end)
            soundbugTasks[playerName] = taskId
            enabled = enabled + 1
        end
    end
    if enabled > 0 then
        user:sendMessage("&aSoundbug enabled for &f" .. enabled .. "&a player(s)")
        log_info("Soundbug enabled for " .. enabled .. " player(s)")
    end
    if disabled > 0 then
        user:sendMessage("&cSoundbug disabled for &f" .. disabled .. "&c player(s)")
        log_info("Soundbug disabled for " .. disabled .. " player(s)")
    end
end)

Command {
    name = 'faketimeout',
    description = 'Simulate server timeout for a player'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: faketimeout <*|player>")
        return
    end
    local target = args[1]
    local players, isAll, errorMsg = getPlayers(target)
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    local enabled, disabled = 0, 0
    for _, player in ipairs(players) do
        local playerName = player:getName()
        if faketimeoutTasks[playerName] then
            cancelTask(faketimeoutTasks[playerName])
            faketimeoutTasks[playerName] = nil
            if player:isOnline() and faketimeoutItems[playerName] then
                pcall(function()
                    local inv = player:getInventory()
                    for _, stack in ipairs(faketimeoutItems[playerName]) do
                        inv:addItem(stack)
                    end
                end)
            end
            faketimeoutItems[playerName] = nil
            disabled = disabled + 1
        else
            faketimeoutItems[playerName] = {}
            local kickDelay = math.random(8, 15) * 20
            local taskId
            taskId = repeatTask(0, 1, function()
                local p = Bukkit:getPlayer(playerName)
                if not p or not p:isOnline() then
                    cancelTask(taskId)
                    faketimeoutTasks[playerName] = nil
                    faketimeoutItems[playerName] = nil
                    return
                end
                pcall(function()
                    local nearby = p:getNearbyEntities(128, 64, 128)
                    for i = 0, nearby:size() - 1 do
                        local e = nearby:get(i)
                        pcall(function()
                            e:setVelocity(Vector:new(0, 0, 0))
                            if e:getType() and tostring(e:getType()):find("FALLING_BLOCK") then
                                e:remove()
                            end
                        end)
                    end
                end)
            end)
            faketimeoutTasks[playerName] = taskId
            delay(kickDelay, function()
                if not faketimeoutTasks[playerName] then return end
                cancelTask(faketimeoutTasks[playerName])
                faketimeoutTasks[playerName] = nil
                faketimeoutItems[playerName] = nil
                local p = Bukkit:getPlayer(playerName)
                if p and p:isOnline() then
                    p:kickPlayer("Timed out")
                end
                log_info("Faketimeout kicked " .. playerName)
            end)
            enabled = enabled + 1
        end
    end
    if enabled > 0 then
        user:sendMessage("&aFaketimeout enabled for &f" .. enabled .. "&a player(s)")
        log_info("Faketimeout enabled for " .. enabled .. " player(s)")
    end
    if disabled > 0 then
        user:sendMessage("&cFaketimeout disabled for &f" .. disabled .. "&c player(s)")
        log_info("Faketimeout disabled for " .. disabled .. " player(s)")
    end
end)

Command {
    name = 'reversehit',
    description = 'Toggle reversehit - attacker gets damage and knockback'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: reversehit <*|player>")
        return
    end
    local target = args[1]
    local players, isAll, errorMsg = getPlayers(target)
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    local enabled, disabled = 0, 0
    for _, player in ipairs(players) do
        local playerName = player:getName()
        if reversehitPlayers[playerName] then
            reversehitPlayers[playerName] = nil
            disabled = disabled + 1
        else
            reversehitPlayers[playerName] = true
            enabled = enabled + 1
        end
    end
    if enabled > 0 then
        user:sendMessage("&aReversehit enabled for &f" .. enabled .. "&a player(s)")
        log_info("Reversehit enabled for " .. enabled .. " player(s)")
    end
    if disabled > 0 then
        user:sendMessage("&cReversehit disabled for &f" .. disabled .. "&c player(s)")
        log_info("Reversehit disabled for " .. disabled .. " player(s)")
    end
end)

Command {
    name = 'randomslot',
    description = 'Randomly change selected hotbar slot every N seconds'
} (function(user, args)
    if #args < 2 then
        user:sendMessage("&cUsage: randomslot <*|player> <seconds>")
        return
    end
    local interval = tonumber(args[2])
    if not interval or interval <= 0 then
        user:sendMessage("&cInvalid seconds value")
        return
    end
    local ticks = math.floor(interval * 20)
    local target = args[1]
    local players, isAll, errorMsg = getPlayers(target)
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    local enabled, disabled = 0, 0
    for _, player in ipairs(players) do
        local playerName = player:getName()
        if randomslotTasks[playerName] then
            cancelTask(randomslotTasks[playerName])
            randomslotTasks[playerName] = nil
            disabled = disabled + 1
        else
            local taskId
            taskId = repeatTask(0, ticks, function()
                local p = Bukkit:getPlayer(playerName)
                if not p or not p:isOnline() then
                    cancelTask(taskId)
                    randomslotTasks[playerName] = nil
                    return
                end
                p:getInventory():setHeldItemSlot(math.random(0, 8))
            end)
            randomslotTasks[playerName] = taskId
            enabled = enabled + 1
        end
    end
    if enabled > 0 then
        user:sendMessage("&aRandomslot enabled for &f" .. enabled .. "&a player(s) (interval: &f" .. interval .. "&as)")
        log_info("Randomslot enabled for " .. enabled .. " player(s)")
    end
    if disabled > 0 then
        user:sendMessage("&cRandomslot disabled for &f" .. disabled .. "&c player(s)")
        log_info("Randomslot disabled for " .. disabled .. " player(s)")
    end
end)

Command {
    name = 'crash',
    description = 'Spam particles and sounds to crash a player client'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: crash <*|player>")
        return
    end
    if not crashParticle then
        user:sendMessage("&cNo valid particle found on this server")
        return
    end
    local function startCrash(playerName)
        local tickCount = 0
        local taskId
        taskId = repeatTask(0, 1, function()
            local p = Bukkit:getPlayer(playerName)
            if not p or not p:isOnline() or tickCount > 200 then
                cancelTask(taskId)
                return
            end
            tickCount = tickCount + 1
            pcall(function()
                local loc = p:getLocation()
                for i = 1, 50 do
                    p:spawnParticle(crashParticle, loc, 2147483647, 1.0E8, 1.0E8, 1.0E8, 1.0E8)
                end
                if crashSound then
                    for i = 1, 20 do
                        p:playSound(loc, crashSound, 1000000.0, 0.5)
                    end
                end
            end)
        end)
    end
    local target = args[1]
    local players, isAll, errorMsg = getPlayers(target)
    if not players then
        user:sendMessage("&c" .. errorMsg)
        return
    end
    for _, player in ipairs(players) do
        startCrash(player:getName())
    end
    if isAll then
        user:sendMessage("&aCrashing all players")
        log_info("Crash sent to all players")
    else
        user:sendMessage("&aCrashing &f" .. players[1]:getName())
        log_info("Crash sent to " .. players[1]:getName())
    end
end)

Command {
    name = 'serverlag',
    description = 'Freeze main server thread for N seconds'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: serverlag <seconds>")
        return
    end
    local seconds = tonumber(args[1])
    if not seconds or seconds < 1 or seconds > 300 then
        user:sendMessage("&cSeconds must be between 1 and 300")
        return
    end
    user:sendMessage("&cFreezing server for &f" .. seconds .. "&c seconds...")
    log_info("Serverlag triggered for " .. seconds .. " seconds")
    delay(1, function()
        local iterations = seconds * 16700000
        local x = 0
        for i = 1, iterations do x = x + 1 end
        log_info("Serverlag ended after " .. seconds .. " seconds")
    end)
end)

Command {
    name = 'scripthelp',
    description = 'Show all available script commands'
} (function(user, args)
    user:sendMessage("&7&m--------------------")
    user:sendMessage("&fScript Commands:")
    for _, info in ipairs(commandInfos) do
        local command, description = info:match("([^%-]+)%s%-%s(.+)")
        if command and description then
            user:sendMessage("&a" .. command .. "&7- " .. description)
        end
    end
    user:sendMessage("&7&m--------------------")
end)
