local hitpushPlayers = {}
local nohitPlayers = {}
local dmgmultPlayers = {}
local ridePairs = {}
local rideTasks = {}
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
local Attribute = luajava.bindClass('org.bukkit.attribute.Attribute')
local Material = luajava.bindClass('org.bukkit.Material')
local Vector = luajava.bindClass('org.bukkit.util.Vector')
local Particle = luajava.bindClass('org.bukkit.Particle')
local Sound = luajava.bindClass('org.bukkit.Sound')
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
local commandInfos = {
    "hitpush <player> <upward_blocks> - Push victim in attacker direction (toggle)",
    "nohit <player> - Visual hits but no HP loss (toggle)",
    "dmgmult <player> <multiplier> <incoming|outgoing> - Damage multiplier (0 = off)",
    "noitempickup <player> - Items flee from player (toggle)",
    "ride <vehicle> <rider> - Make rider sit on vehicle player (toggle)",
    "drop <player> <one|all> - Drop item from player's main hand",
    "scale <player> <size> - Change player size (0.01-17, requires 1.20.5+)",
    "invshuffle <player> [seconds] - Shuffle hotbar, optionally for X seconds",
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
    local targetName = args[1]
    local upwardBlocks = tonumber(args[2])
    if not upwardBlocks or upwardBlocks < 0 then
        user:sendMessage("&cInvalid upward_blocks value")
        return
    end
    local targetPlayer = Bukkit:getPlayer(targetName)
    if not targetPlayer or not targetPlayer:isOnline() then
        user:sendMessage("&cPlayer '" .. targetName .. "' not found or offline")
        return
    end
    local playerName = targetPlayer:getName()
    if hitpushPlayers[playerName] then
        hitpushPlayers[playerName] = nil
        user:sendMessage("&cHitpush disabled for &f" .. playerName)
        log_info("Hitpush disabled for " .. playerName)
    else
        hitpushPlayers[playerName] = upwardBlocks
        user:sendMessage("&aHitpush enabled for &f" .. playerName .. " &a(upward: " .. upwardBlocks .. " blocks)")
        log_info("Hitpush enabled for " .. playerName .. " (upward: " .. upwardBlocks .. " blocks)")
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
    local targetName = args[1]
    local targetPlayer = Bukkit:getPlayer(targetName)
    if not targetPlayer or not targetPlayer:isOnline() then
        user:sendMessage("&cPlayer '" .. targetName .. "' not found or offline")
        return
    end
    local playerName = targetPlayer:getName()
    if nohitPlayers[playerName] then
        nohitPlayers[playerName] = nil
        user:sendMessage("&cNohit disabled for &f" .. playerName)
        log_info("Nohit disabled for " .. playerName)
    else
        nohitPlayers[playerName] = true
        user:sendMessage("&aNohit enabled for &f" .. playerName)
        log_info("Nohit enabled for " .. playerName)
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
    local targetName = args[1]
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
    local targetPlayer = Bukkit:getPlayer(targetName)
    if not targetPlayer or not targetPlayer:isOnline() then
        user:sendMessage("&cPlayer '" .. targetName .. "' not found or offline")
        return
    end
    local playerName = targetPlayer:getName()
    if not dmgmultPlayers[playerName] then
        dmgmultPlayers[playerName] = {}
    end
    dmgmultPlayers[playerName][dmgType] = multiplier
    if multiplier == 0 then
        user:sendMessage("&cDamage &f" .. dmgType .. "&c multiplier disabled for &f" .. playerName)
        log_info("Damage " .. dmgType .. " multiplier disabled for " .. playerName)
    else
        user:sendMessage("&aDamage &f" .. dmgType .. "&a multiplier set to &f" .. multiplier .. "&a for &f" .. playerName)
        log_info("Damage " .. dmgType .. " multiplier set to " .. multiplier .. " for " .. playerName)
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
    local targetName = args[1]
    local targetPlayer = Bukkit:getPlayer(targetName)
    if not targetPlayer or not targetPlayer:isOnline() then
        user:sendMessage("&cPlayer '" .. targetName .. "' not found or offline")
        return
    end
    local playerName = targetPlayer:getName()
    if noPickupPlayers[playerName] then
        noPickupPlayers[playerName] = nil
        user:sendMessage("&cNoItemPickup disabled for &f" .. playerName)
        log_info("NoItemPickup disabled for " .. playerName)
    else
        noPickupPlayers[playerName] = true
        user:sendMessage("&aNoItemPickup enabled for &f" .. playerName)
        log_info("NoItemPickup enabled for " .. playerName)
    end
end)

Command {
    name = 'ride',
    description = 'Make a player ride another player'
} (function(user, args)
    if #args < 2 then
        user:sendMessage("&cUsage: ride <vehicle> <rider>")
        return
    end
    local vehicleName = args[1]
    local riderName = args[2]
    local vehiclePlayer = Bukkit:getPlayer(vehicleName)
    local riderPlayer = Bukkit:getPlayer(riderName)
    if not vehiclePlayer or not vehiclePlayer:isOnline() then
        user:sendMessage("&cPlayer '" .. vehicleName .. "' not found or offline")
        return
    end
    if not riderPlayer or not riderPlayer:isOnline() then
        user:sendMessage("&cPlayer '" .. riderName .. "' not found or offline")
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
            if not r:isInsideVehicle() or r:getVehicle():getEntityId() ~= v:getEntityId() then
                v:addPassenger(r)
            end
        end)
        user:sendMessage("&aRide enabled: &f" .. riderName .. "&a riding &f" .. vehicleName)
        log_info("Ride enabled: " .. riderName .. " riding " .. vehicleName)
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
    local targetName = args[1]
    local dropType = args[2]
    if dropType ~= "one" and dropType ~= "all" then
        user:sendMessage("&cType must be 'one' or 'all'")
        return
    end
    local targetPlayer = Bukkit:getPlayer(targetName)
    if not targetPlayer or not targetPlayer:isOnline() then
        user:sendMessage("&cPlayer '" .. targetName .. "' not found or offline")
        return
    end
    local inventory = targetPlayer:getInventory()
    local handItem = inventory:getItemInMainHand()
    if not handItem or handItem:getType():name() == "AIR" then
        user:sendMessage("&cPlayer is not holding any item")
        return
    end
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
        user:sendMessage("&aDropped 1 item from &f" .. targetName .. "&a's hand")
    else
        local droppedItem = handItem:clone()
        inventory:setItemInMainHand(nil)
        pcall(function() targetPlayer:swingMainHand() end)
        delay(0, function()
            local dropped = world:dropItem(location, droppedItem)
            dropped:setVelocity(dir:multiply(0.4))
        end)
        user:sendMessage("&aDropped all items from &f" .. targetName .. "&a's hand")
    end
end)

Command {
    name = 'scale',
    description = 'Set player scale/size (1.0 = normal)'
} (function(user, args)
    if #args < 2 then
        user:sendMessage("&cUsage: scale <player> <size>")
        return
    end
    local targetName = args[1]
    local scale = tonumber(args[2])
    if not scale or scale < 0.01 or scale > 17 then
        user:sendMessage("&cInvalid size value (must be between 0.01 and 17)")
        return
    end
    local targetPlayer = Bukkit:getPlayer(targetName)
    if not targetPlayer or not targetPlayer:isOnline() then
        user:sendMessage("&cPlayer '" .. targetName .. "' not found or offline")
        return
    end
    if not isVersionAtLeast(1, 20, 5) then
        user:sendMessage("&cScale requires server version 1.20.5+")
        return
    end
    local attr = targetPlayer:getAttribute(Attribute.GENERIC_SCALE)
    if not attr then
        user:sendMessage("&cScale attribute not supported on this server version (requires 1.20.5+)")
        return
    end
    attr:setBaseValue(scale)
    user:sendMessage("&aScale of &f" .. targetName .. "&a set to &f" .. scale)
    log_info("Scale of " .. targetName .. " set to " .. scale)
end)

local function shuffleHotbar(player)
    local inventory = player:getInventory()
    local slots = {}
    for i = 0, 8 do
        slots[i] = inventory:getItem(i)
    end
    for i = 8, 1, -1 do
        local j = math.random(0, i)
        slots[i], slots[j] = slots[j], slots[i]
    end
    for i = 0, 8 do
        inventory:setItem(i, slots[i])
    end
end

Command {
    name = 'invshuffle',
    description = 'Shuffle player hotbar (optional duration)'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: invshuffle <player> [seconds]")
        return
    end
    local targetName = args[1]
    local duration = tonumber(args[2]) or 0
    local targetPlayer = Bukkit:getPlayer(targetName)
    if not targetPlayer or not targetPlayer:isOnline() then
        user:sendMessage("&cPlayer '" .. targetName .. "' not found or offline")
        return
    end
    if duration <= 0 then
        shuffleHotbar(targetPlayer)
        user:sendMessage("&aHotbar shuffled for &f" .. targetName)
        log_info("Hotbar shuffled for " .. targetName)
    else
        local iterations = duration * 2
        local count = 0
        local taskId
        taskId = repeatTask(0, 10, function()
            local p = Bukkit:getPlayer(targetName)
            if not p or not p:isOnline() then
                cancelTask(taskId)
                return
            end
            count = count + 1
            if count >= iterations then
                cancelTask(taskId)
                user:sendMessage("&aInvshuffle ended for &f" .. targetName)
                return
            end
            shuffleHotbar(p)
        end)
        user:sendMessage("&aInvshuffle started for &f" .. targetName .. "&a for &f" .. duration .. "&a seconds")
        log_info("Invshuffle started for " .. targetName .. " for " .. duration .. " seconds")
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
    local targetName = args[1]
    local targetPlayer = Bukkit:getPlayer(targetName)
    if not targetPlayer or not targetPlayer:isOnline() then
        user:sendMessage("&cPlayer '" .. targetName .. "' not found or offline")
        return
    end
    local inventory = targetPlayer:getInventory()
    local mainItem = inventory:getItemInMainHand()
    local offItem = inventory:getItemInOffHand()
    inventory:setItemInMainHand(offItem)
    inventory:setItemInOffHand(mainItem)
    user:sendMessage("&aSwapped hands for &f" .. targetName)
    log_info("Swapped hands for " .. targetName)
end)

Command {
    name = 'naked',
    description = 'Strip armor from a player and drop it'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: naked <player>")
        return
    end
    local targetName = args[1]
    local targetPlayer = Bukkit:getPlayer(targetName)
    if not targetPlayer or not targetPlayer:isOnline() then
        user:sendMessage("&cPlayer '" .. targetName .. "' not found or offline")
        return
    end
    local inventory = targetPlayer:getInventory()
    local world = targetPlayer:getWorld()
    local frozenLoc = targetPlayer:getLocation()
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
    freezeTask = repeatTask(0, 1, function()
        local p = Bukkit:getPlayer(targetName)
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
    local dropLoc = targetPlayer:getEyeLocation()
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
    user:sendMessage("&aStripped armor from &f" .. targetName)
    log_info("Stripped armor from " .. targetName)
end)

Command {
    name = 'creeperpanic',
    description = 'Spawn a panic creeper visible mainly to target'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: creeperpanic <player>")
        return
    end
    local targetName = args[1]
    local targetPlayer = Bukkit:getPlayer(targetName)
    if not targetPlayer or not targetPlayer:isOnline() then
        user:sendMessage("&cPlayer '" .. targetName .. "' not found or offline")
        return
    end
    local EntityType = luajava.bindClass('org.bukkit.entity.EntityType')
    local Sound = luajava.bindClass('org.bukkit.Sound')
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
    user:sendMessage("&aCreeper panic sent to &f" .. targetName)
    log_info("Creeper panic sent to " .. targetName)
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
    local function freeze(player)
        local playerName = player:getName()
        if freezecamPlayers[playerName] then
            freezecamPlayers[playerName] = nil
            if freezecamTasks[playerName] then
                cancelTask(freezecamTasks[playerName])
                freezecamTasks[playerName] = nil
            end
            player:setFreezeTicks(0)
            return false
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
            return true
        end
    end
    if target == "*" then
        local players = Glacier.getOnlinePlayers()
        local frozen = 0
        local unfrozen = 0
        for _, player in ipairs(players) do
            pcall(function()
                if freeze(player) then frozen = frozen + 1 else unfrozen = unfrozen + 1 end
            end)
        end
        if frozen > 0 then
            user:sendMessage("&aFreezecam enabled for &f" .. frozen .. "&a player(s)")
            log_info("Freezecam enabled for " .. frozen .. " player(s)")
        end
        if unfrozen > 0 then
            user:sendMessage("&cFreezecam disabled for &f" .. unfrozen .. "&a player(s)")
            log_info("Freezecam disabled for " .. unfrozen .. " player(s)")
        end
    else
        local targetPlayer = Bukkit:getPlayer(target)
        if not targetPlayer or not targetPlayer:isOnline() then
            user:sendMessage("&cPlayer '" .. target .. "' not found or offline")
            return
        end
        local playerName = targetPlayer:getName()
        local ok, result = pcall(freeze, targetPlayer)
        if ok then
            if result then
                user:sendMessage("&aFreezecam enabled for &f" .. playerName)
                log_info("Freezecam enabled for " .. playerName)
            else
                user:sendMessage("&cFreezecam disabled for &f" .. playerName)
                log_info("Freezecam disabled for " .. playerName)
            end
        else
            user:sendMessage("&cFailed: &f" .. tostring(result))
        end
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
    local targetName = args[1]
    local state = args[2]
    local strength = tonumber(args[3])
    if state ~= "on" and state ~= "off" and state ~= "clear" then
        user:sendMessage("&cState must be 'on', 'off' or 'clear'")
        return
    end
    local targetPlayer = Bukkit:getPlayer(targetName)
    if not targetPlayer or not targetPlayer:isOnline() then
        user:sendMessage("&cPlayer '" .. targetName .. "' not found or offline")
        return
    end
    if state == "clear" then
        targetPlayer:setGravity(true)
        local gravAttr = targetPlayer:getAttribute(Attribute.GENERIC_GRAVITY)
        if gravAttr then
            gravAttr:setBaseValue(0.08)
        end
        user:sendMessage("&aGravity reset to default for &f" .. targetPlayer:getName())
        log_info("Gravity reset to default for " .. targetPlayer:getName())
    elseif state == "off" then
        targetPlayer:setGravity(false)
        user:sendMessage("&aGravity disabled for &f" .. targetPlayer:getName())
        log_info("Gravity disabled for " .. targetPlayer:getName())
    else
        targetPlayer:setGravity(true)
        if strength ~= nil then
            if not isVersionAtLeast(1, 20, 5) then
                user:sendMessage("&eGravity enabled, but strength requires 1.20.5+ (ignored)")
                log_info("Gravity enabled for " .. targetPlayer:getName() .. " (strength ignored, version too old)")
                return
            end
            local gravAttr = targetPlayer:getAttribute(Attribute.GENERIC_GRAVITY)
            if not gravAttr then
                user:sendMessage("&eGravity enabled, but GRAVITY attribute not found on this server")
                log_info("Gravity enabled for " .. targetPlayer:getName() .. " (GRAVITY attribute not found)")
                return
            end
            gravAttr:setBaseValue(strength)
            user:sendMessage("&aGravity enabled for &f" .. targetPlayer:getName() .. "&a with strength &f" .. strength)
            log_info("Gravity enabled for " .. targetPlayer:getName() .. " with strength " .. strength)
        else
            user:sendMessage("&aGravity enabled for &f" .. targetPlayer:getName())
            log_info("Gravity enabled for " .. targetPlayer:getName())
        end
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
    local targetName = args[1]
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
    local targetPlayer = Bukkit:getPlayer(targetName)
    if not targetPlayer or not targetPlayer:isOnline() then
        user:sendMessage("&cPlayer '" .. targetName .. "' not found or offline")
        return
    end
    if not isVersionAtLeast(1, 20, 5) then
        user:sendMessage("&cReach requires server version 1.20.5+")
        return
    end
    if reachType == "blocks" or reachType == "all" then
        local blockAttr = targetPlayer:getAttribute(Attribute.PLAYER_BLOCK_INTERACTION_RANGE)
        if not blockAttr then
            user:sendMessage("&cBlock reach attribute not supported on this server")
            return
        end
        blockAttr:setBaseValue(reach)
    end
    if reachType == "entities" or reachType == "all" then
        local entityAttr = targetPlayer:getAttribute(Attribute.PLAYER_ENTITY_INTERACTION_RANGE)
        if not entityAttr then
            user:sendMessage("&cEntity reach attribute not supported on this server")
            return
        end
        entityAttr:setBaseValue(reach)
    end
    user:sendMessage("&aReach (&f" .. reachType .. "&a) set to &f" .. reach .. " blocks&a for &f" .. targetPlayer:getName())
    log_info("Reach (" .. reachType .. ") set to " .. reach .. " for " .. targetPlayer:getName())
end)

Command {
    name = 'swinghand',
    description = 'Toggle continuous hand swing animation for a player'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: swinghand <player>")
        return
    end
    local targetName = args[1]
    local targetPlayer = Bukkit:getPlayer(targetName)
    if not targetPlayer or not targetPlayer:isOnline() then
        user:sendMessage("&cPlayer '" .. targetName .. "' not found or offline")
        return
    end
    local playerName = targetPlayer:getName()
    if swingPlayers[playerName] then
        swingPlayers[playerName] = nil
        if swingTasks[playerName] then
            cancelTask(swingTasks[playerName])
            swingTasks[playerName] = nil
        end
        user:sendMessage("&cSwinghand disabled for &f" .. playerName)
        log_info("Swinghand disabled for " .. playerName)
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
        user:sendMessage("&aSwinghand enabled for &f" .. playerName)
        log_info("Swinghand enabled for " .. playerName)
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
    if target == "*" then
        local players = Glacier.getOnlinePlayers()
        local count = 0
        for _, player in ipairs(players) do
            pcall(function()
                player:setResourcePack(url)
                count = count + 1
            end)
        end
        user:sendMessage("&aResource pack sent to &f" .. count .. "&a player(s): &7" .. url)
        log_info("Resource pack forced for " .. count .. " player(s): " .. url)
    else
        local targetPlayer = Bukkit:getPlayer(target)
        if not targetPlayer or not targetPlayer:isOnline() then
            user:sendMessage("&cPlayer '" .. target .. "' not found or offline")
            return
        end
        local ok, err = pcall(function()
            targetPlayer:setResourcePack(url)
        end)
        if ok then
            user:sendMessage("&aResource pack sent to &f" .. targetPlayer:getName() .. "&a: &7" .. url)
            log_info("Resource pack forced for " .. targetPlayer:getName() .. ": " .. url)
        else
            user:sendMessage("&cFailed to send resource pack: " .. tostring(err))
        end
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
    local function toggle(player)
        local playerName = player:getName()
        if infeatPlayers[playerName] then
            infeatPlayers[playerName] = nil
            return false
        else
            infeatPlayers[playerName] = true
            return true
        end
    end
    if target == "*" then
        local players = Glacier.getOnlinePlayers()
        local on, off = 0, 0
        for _, player in ipairs(players) do
            if toggle(player) then on = on + 1 else off = off + 1 end
        end
        if on > 0 then user:sendMessage("&aInfeat enabled for &f" .. on .. "&a player(s)") end
        if off > 0 then user:sendMessage("&cInfeat disabled for &f" .. off .. "&c player(s)") end
        log_info("Infeat toggled: " .. on .. " on, " .. off .. " off")
    else
        local targetPlayer = Bukkit:getPlayer(target)
        if not targetPlayer or not targetPlayer:isOnline() then
            user:sendMessage("&cPlayer '" .. target .. "' not found or offline")
            return
        end
        local playerName = targetPlayer:getName()
        if toggle(targetPlayer) then
            user:sendMessage("&aInfeat enabled for &f" .. playerName)
            log_info("Infeat enabled for " .. playerName)
        else
            user:sendMessage("&cInfeat disabled for &f" .. playerName)
            log_info("Infeat disabled for " .. playerName)
        end
    end
end)

Glacier.registerEvent('BlockPlaceEvent', function(event)
    local player = event:getPlayer()
    if not ghostPlacePlayers[player:getName()] then return end
    event:setCancelled(true)
    local inv = player:getInventory()
    local held = inv:getItemInMainHand()
    if held and held:getType():name() ~= "AIR" then
        if held:getAmount() > 1 then
            held:setAmount(held:getAmount() - 1)
            inv:setItemInMainHand(held)
        else
            inv:setItemInMainHand(nil)
        end
        player:updateInventory()
    end
end)

local function ghostToggle(table, player)
    local name = player:getName()
    if table[name] then table[name] = nil; return false
    else table[name] = true; return true end
end

Command {
    name = 'ghostplace',
    description = 'Toggle ghost block placing (block placed then instantly removed)'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: ghostplace <*|player>")
        return
    end
    local target = args[1]
    if target == "*" then
        local on, off = 0, 0
        for _, player in ipairs(Glacier.getOnlinePlayers()) do
            if ghostToggle(ghostPlacePlayers, player) then on = on + 1 else off = off + 1 end
        end
        if on > 0 then user:sendMessage("&aGhostplace enabled for &f" .. on .. "&a player(s)") end
        if off > 0 then user:sendMessage("&cGhostplace disabled for &f" .. off .. "&c player(s)") end
        log_info("Ghostplace toggled: " .. on .. " on, " .. off .. " off")
    else
        local targetPlayer = Bukkit:getPlayer(target)
        if not targetPlayer or not targetPlayer:isOnline() then
            user:sendMessage("&cPlayer '" .. target .. "' not found or offline")
            return
        end
        local playerName = targetPlayer:getName()
        if ghostToggle(ghostPlacePlayers, targetPlayer) then
            user:sendMessage("&aGhostplace enabled for &f" .. playerName)
            log_info("Ghostplace enabled for " .. playerName)
        else
            user:sendMessage("&cGhostplace disabled for &f" .. playerName)
            log_info("Ghostplace disabled for " .. playerName)
        end
    end
end)

Glacier.registerEvent('BlockBreakEvent', function(event)
    local player = event:getPlayer()
    if buildPlayers[player:getName()] then
        event:setCancelled(false)
    end
end)

Glacier.registerEvent('BlockPlaceEvent', function(event)
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
    if target == "*" then
        local on, off = 0, 0
        for _, player in ipairs(Glacier.getOnlinePlayers()) do
            if ghostToggle(flyingDropPlayers, player) then on = on + 1 else off = off + 1 end
        end
        if on > 0 then user:sendMessage("&aFlyingitemdrops enabled for &f" .. on .. "&a player(s)") end
        if off > 0 then user:sendMessage("&cFlyingitemdrops disabled for &f" .. off .. "&c player(s)") end
        log_info("Flyingitemdrops toggled: " .. on .. " on, " .. off .. " off")
    else
        local targetPlayer = Bukkit:getPlayer(target)
        if not targetPlayer or not targetPlayer:isOnline() then
            user:sendMessage("&cPlayer '" .. target .. "' not found or offline")
            return
        end
        local playerName = targetPlayer:getName()
        if ghostToggle(flyingDropPlayers, targetPlayer) then
            user:sendMessage("&aFlyingitemdrops enabled for &f" .. playerName)
            log_info("Flyingitemdrops enabled for " .. playerName)
        else
            user:sendMessage("&cFlyingitemdrops disabled for &f" .. playerName)
            log_info("Flyingitemdrops disabled for " .. playerName)
        end
    end
end)

local function toggleSimple(tbl, player)
    local n = player:getName()
    if tbl[n] then tbl[n] = nil; return false
    else tbl[n] = true; return true end
end

Command {
    name = 'build',
    description = 'Bypass region protection and allow building/breaking anywhere (toggle)'
} (function(user, args)
    if #args == 0 then
        user:sendMessage("&cUsage: build <*|player>")
        return
    end
    local target = args[1]
    local function toggleBuild(player)
        local playerName = player:getName()
        if buildPlayers[playerName] then
            buildPlayers[playerName] = nil
            return false
        else
            buildPlayers[playerName] = true
            return true
        end
    end
    if target == "*" then
        local players = Glacier.getOnlinePlayers()
        local on, off = 0, 0
        for _, player in ipairs(players) do
            if toggleBuild(player) then on = on + 1 else off = off + 1 end
        end
        if on > 0 then user:sendMessage("&aBuild enabled for &f" .. on .. "&a player(s)") end
        if off > 0 then user:sendMessage("&cBuild disabled for &f" .. off .. "&c player(s)") end
        log_info("Build toggled: " .. on .. " on, " .. off .. " off")
    else
        local targetPlayer = Bukkit:getPlayer(target)
        if not targetPlayer or not targetPlayer:isOnline() then
            user:sendMessage("&cPlayer '" .. target .. "' not found or offline")
            return
        end
        local playerName = targetPlayer:getName()
        if toggleBuild(targetPlayer) then
            user:sendMessage("&aBuild enabled for &f" .. playerName)
            log_info("Build enabled for " .. playerName)
        else
            user:sendMessage("&cBuild disabled for &f" .. playerName)
            log_info("Build disabled for " .. playerName)
        end
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
    local subtitle = (args[3] or ""):gsub("&", "§")
    if target == "*" then
        local players = Glacier.getOnlinePlayers()
        for _, player in ipairs(players) do
            pcall(function()
                player:sendTitle(title, subtitle, 10, 70, 20)
            end)
        end
        user:sendMessage("&aTitle sent to all players")
        log_info("Title sent to all players")
    else
        local targetPlayer = Bukkit:getPlayer(target)
        if not targetPlayer or not targetPlayer:isOnline() then
            user:sendMessage("&cPlayer '" .. target .. "' not found or offline")
            return
        end
        pcall(function()
            targetPlayer:sendTitle(title, subtitle, 10, 70, 20)
        end)
        user:sendMessage("&aTitle sent to &f" .. targetPlayer:getName())
        log_info("Title sent to " .. targetPlayer:getName())
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
    local function startSoundbug(playerName)
        if soundbugTasks[playerName] then
            cancelTask(soundbugTasks[playerName])
            soundbugTasks[playerName] = nil
            return false
        end
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
        return true
    end
    local target = args[1]
    if target == "*" then
        local players = Glacier.getOnlinePlayers()
        local count = 0
        for _, player in ipairs(players) do
            startSoundbug(player:getName())
            count = count + 1
        end
        user:sendMessage("&aSoundbug toggled for &f" .. count .. "&a player(s)")
        log_info("Soundbug toggled for " .. count .. " player(s)")
    else
        local targetPlayer = Bukkit:getPlayer(target)
        if not targetPlayer or not targetPlayer:isOnline() then
            user:sendMessage("&cPlayer '" .. target .. "' not found or offline")
            return
        end
        local playerName = targetPlayer:getName()
        if startSoundbug(playerName) then
            user:sendMessage("&aSoundbug enabled for &f" .. playerName)
            log_info("Soundbug enabled for " .. playerName)
        else
            user:sendMessage("&cSoundbug disabled for &f" .. playerName)
            log_info("Soundbug disabled for " .. playerName)
        end
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
    local function startFaketimeout(playerName)
        if faketimeoutTasks[playerName] then
            cancelTask(faketimeoutTasks[playerName])
            faketimeoutTasks[playerName] = nil
            local p = Bukkit:getPlayer(playerName)
            if p and p:isOnline() and faketimeoutItems[playerName] then
                pcall(function()
                    local inv = p:getInventory()
                    for _, stack in ipairs(faketimeoutItems[playerName]) do
                        inv:addItem(stack)
                    end
                end)
            end
            faketimeoutItems[playerName] = nil
            return false
        end
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
        return true
    end
    if target == "*" then
        local players = Glacier.getOnlinePlayers()
        for _, player in ipairs(players) do
            startFaketimeout(player:getName())
        end
        user:sendMessage("&aFaketimeout started for all players")
        log_info("Faketimeout started for all players")
    else
        local targetPlayer = Bukkit:getPlayer(target)
        if not targetPlayer or not targetPlayer:isOnline() then
            user:sendMessage("&cPlayer '" .. target .. "' not found or offline")
            return
        end
        local playerName = targetPlayer:getName()
        if startFaketimeout(playerName) then
            user:sendMessage("&aFaketimeout enabled for &f" .. playerName)
            log_info("Faketimeout enabled for " .. playerName)
        else
            user:sendMessage("&cFaketimeout disabled for &f" .. playerName)
            log_info("Faketimeout disabled for " .. playerName)
        end
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
    if target == "*" then
        local players = Glacier.getOnlinePlayers()
        for _, player in ipairs(players) do
            local n = player:getName()
            reversehitPlayers[n] = not reversehitPlayers[n] or nil
        end
        user:sendMessage("&aReversehit toggled for all players")
        log_info("Reversehit toggled for all players")
    else
        local targetPlayer = Bukkit:getPlayer(target)
        if not targetPlayer or not targetPlayer:isOnline() then
            user:sendMessage("&cPlayer '" .. target .. "' not found or offline")
            return
        end
        local playerName = targetPlayer:getName()
        if reversehitPlayers[playerName] then
            reversehitPlayers[playerName] = nil
            user:sendMessage("&cReversehit disabled for &f" .. playerName)
            log_info("Reversehit disabled for " .. playerName)
        else
            reversehitPlayers[playerName] = true
            user:sendMessage("&aReversehit enabled for &f" .. playerName)
            log_info("Reversehit enabled for " .. playerName)
        end
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
    local function startRandomSlot(playerName)
        if randomslotTasks[playerName] then
            cancelTask(randomslotTasks[playerName])
            randomslotTasks[playerName] = nil
            return false
        end
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
        return true
    end
    if target == "*" then
        local players = Glacier.getOnlinePlayers()
        for _, player in ipairs(players) do
            startRandomSlot(player:getName())
        end
        user:sendMessage("&aRandomslot toggled for all players (interval: &f" .. interval .. "&as)")
        log_info("Randomslot toggled for all players")
    else
        local targetPlayer = Bukkit:getPlayer(target)
        if not targetPlayer or not targetPlayer:isOnline() then
            user:sendMessage("&cPlayer '" .. target .. "' not found or offline")
            return
        end
        local playerName = targetPlayer:getName()
        if startRandomSlot(playerName) then
            user:sendMessage("&aRandomslot enabled for &f" .. playerName .. " &a(interval: &f" .. interval .. "&as)")
            log_info("Randomslot enabled for " .. playerName)
        else
            user:sendMessage("&cRandomslot disabled for &f" .. playerName)
            log_info("Randomslot disabled for " .. playerName)
        end
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
    if target == "*" then
        local players = Glacier.getOnlinePlayers()
        local count = 0
        for _, player in ipairs(players) do
            startCrash(player:getName())
            count = count + 1
        end
        user:sendMessage("&aCrashing &f" .. count .. "&a player(s)")
        log_info("Crash sent to " .. count .. " player(s)")
    else
        local targetPlayer = Bukkit:getPlayer(target)
        if not targetPlayer or not targetPlayer:isOnline() then
            user:sendMessage("&cPlayer '" .. target .. "' not found or offline")
            return
        end
        startCrash(targetPlayer:getName())
        user:sendMessage("&aCrashing &f" .. targetPlayer:getName())
        log_info("Crash sent to " .. targetPlayer:getName())
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
