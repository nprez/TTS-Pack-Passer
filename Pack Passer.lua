local zone1 = self
local zone2 = self
local zone3 = self

--expected offsets for zones
local zoneXZOffset = 3.75
local zoneYOffset = 1.56

--expected scales for zones
local zoneXScale = 3.25
local zoneYScale = 3
local zoneZScale = 4.5

--expected scales for pack passer
local passerXScale = 12
local passerYScale = 0.1
local passerZScale = 2.5

--lock to prevent race conditions
local inUse = false

local zonesSetup = false

function sin(theta)
    return math.sin(math.rad(theta))
end
function cos(theta)
    return math.cos(math.rad(theta))
end

function onload()
    createClickButtons()
end

function onDestroy()
    if zonesSetup then
        destroyObject(zone1)
        destroyObject(zone2)
        destroyObject(zone3)
    end
end

function createClickButtons()
    self.createButton({
        label='Take', click_function='takeRightPlayer', function_owner=self,
        position={-0.4,1,-0.6}, scale={x=0.25, y=0.5, z=0.5}, rotation={0,180,0}, width=420, height=200, font_size=180, color={r=0, g=64, b=0}
    })
    self.createButton({
        label='Pass', click_function='passRightPlayer', function_owner=self,
        position={-0.4,1,0.6}, scale={x=0.25, y=0.5, z=0.5}, rotation={0,180,0}, width=420, height=200, font_size=180, color={r=64, g=0, b=0}
    })
    self.createButton({
        label='Take', click_function='takeLeftPlayer', function_owner=self,
        position={0.4,1,-0.6}, scale={x=0.25, y=0.5, z=0.5}, rotation={0,180,0}, width=420, height=200, font_size=180, color={r=0, g=64, b=0}
    })
    self.createButton({
        label='Pass', click_function='passLeftPlayer', function_owner=self,
        position={0.4,1,0.6}, scale={x=0.25, y=0.5, z=0.5}, rotation={0,180,0}, width=420, height=200, font_size=180, color={r=64, g=0, b=0}
    })
end
function takeRightPlayer(obj, color)
    take(false, color)
end
function passRightPlayer(obj, color)
    pass(false, color)
end
function takeLeftPlayer(obj, color)
    take(true, color)
end
function passLeftPlayer(obj, color)
    pass(true, color)
end

function updateZones()
    if not zonesSetup then
        zone1 = spawnObject({type="ScriptingTrigger"})
        zone2 = spawnObject({type="ScriptingTrigger"})
        zone3 = spawnObject({type="ScriptingTrigger"})
        zonesSetup = true
    end
    
    --set actual scales for zones
    local scale = self.getScale()
    local scaleX = (zoneXScale*scale.x)/passerXScale
    local scaleY = (zoneYScale*scale.y)/passerYScale
    local scaleZ = (zoneZScale*scale.z)/passerZScale
    zone1.setScale({scaleX, scaleY, scaleZ})
    zone2.setScale({scaleX, scaleY, scaleZ})
    zone3.setScale({scaleX, scaleY, scaleZ})
    
    --set actual positions for zones based on offsets
    local pos = self.getPosition()
    local yOffset = (zoneYOffset*scaleY)/(zoneYScale)
    local xOffset = (zoneXZOffset*scaleX)/(zoneXScale)*cos(self.getRotation().y)
    local zOffset = (zoneXZOffset*scaleZ)/(zoneZScale)*sin(self.getRotation().y)
    zone1.setPosition({pos.x-xOffset, pos.y+yOffset, pos.z+zOffset})
    zone2.setPosition({pos.x, pos.y+yOffset, pos.z})
    zone3.setPosition({pos.x+xOffset, pos.y+yOffset, pos.z-zOffset})
    
    --set rotations for zones to match the pack passer
    zone1.setRotation(self.getRotation())
    zone2.setRotation(self.getRotation())
    zone3.setRotation(self.getRotation())
end

function take(leftPlayer, color)
    if inUse then
        printToColor("Pack passer is currently busy", color, {r=255, g=0, b=0})
        return
    end
    inUse = true
    updateZones()
    if #Player[color].getHandObjects() > 0 then
        printToColor("Pass your pack before taking a new one, "..Player[color].steam_name, color, {r=255, g=0, b=0})
        inUse = false
        return
    end
    local z1 = zone1.getObjects()
    local z2 = zone2.getObjects()
    local z3 = zone3.getObjects()
    local pos1 = zone1.getPosition()
    local pos2 = zone2.getPosition()
    local pos3 = zone3.getPosition()
    
    local zones = {z1, z2, z3}
    local positions = {pos1, pos2, pos3}
    local haveTaken = false
    
    if not leftPlayer then
        zones = {z3, z2, z1}
        positions = {pos3, pos2, pos1}
    end
    
    for i=1,3 do
        if #zones[i] > 0 then
            local deck = zones[i][1]
            --take pack
            if not haveTaken then
                if deck.type == "Card" then
                    deck.deal(1, color)
                    haveTaken = true
                elseif deck.type == "Deck" then
                    deck.deal(deck.getQuantity(), color)
                    haveTaken = true
                end
            --move pack
            else
                local j = i-1
                while j-1 > 0 and #zones[j-1] == 0 do
                    j = j-1
                end
                deck.setPosition(positions[j])
                deck.setVelocity(Vector(0, -1, 0))
            end
        end
    end
    if not haveTaken then
        printToColor("No pack to take, "..Player[color].steam_name, color, {r=255, g=0, b=0})
        inUse = false
        return
    end
    inUse = false
end

function pass(leftPlayer, color)
    if inUse then
        printToColor("Pack passer is currently busy", color, {r=255, g=0, b=0})
        return
    end
    inUse = true
    updateZones()
    local z1 = zone1.getObjects()
    local z2 = zone2.getObjects()
    local z3 = zone3.getObjects()
    local pos1 = zone1.getPosition()
    local pos2 = zone2.getPosition()
    local pos3 = zone3.getPosition()
    local rot = self.getRotation()
    local newRot = {180, rot[2], rot[3]}
    
    local hand = Player[color].getHandObjects()
    if #hand == 0 then
        inUse = false
        return
    end
    
    local zones = {z3, z2, z1}
    local positions = {pos3, pos2, pos1}
    
    if not leftPlayer then
        zones = {z1, z2, z3}
        positions = {pos1, pos2, pos3}
    end
    
    --move existing packs
    local occupied = {#zones[1]>0, #zones[2]>0, #zones[3]>0}
    for i=2,3 do
        if occupied[i] then
            local j = 1
            while j<i and occupied[j] do
                j = j+1
            end
            if not occupied[j] then
                local deck = zones[i][1]
                deck.setPosition(positions[j])
                deck.setVelocity(Vector(0, -1, 0))
                occupied[j] = true
                occupied[i] = false
            end
        end
    end
    
    --pass pack
    local passTo = -1
    for i=1,3 do
        if not occupied[i] then
            passTo = i
            break
        end
    end
    if passTo > 0 then
        local shuffled = {}
        for i, v in ipairs(hand) do
            local pos = math.random(1, #shuffled+1)
            table.insert(shuffled, pos, v)
        end
        for k, v in pairs(shuffled) do
            v.setPosition(positions[passTo])
            v.setRotation(newRot)
            v.setVelocity(Vector(0, -1, 0))
        end
    else
        printToColor("Slow down, "..Player[color].steam_name, color, {r=255, g=0, b=0})
        inUse = false
        return
    end
    inUse = false
end