local game = {}

function game.print(...)
    print(...)
    sleep(0.25)
end

function game.write(...)
    write(...)
    sleep(0.25)
end

function game.printSlow(str)
    for char in str:gmatch(".") do
        write(char)
        sleep(0.05)
    end
    print()
end

function game.writeSlow(str)
    for char in str:gmatch(".") do
        write(char)
        sleep(0.05)
    end
    print()
end

-- true - alive
--
-- false - dead/empty
---@type boolean[]
local shells = {}
game.initLive = 0
game.initCount = 0

-- items to implement:
-- beer, handcuffs, magnifying glass, phone, handsaw, cigarettes

---@alias game.item "beer"
---| "saw"
---| "handcuffs"
---| "cigarettes"
---| "phone"
---| "magnifying glass"
---| "adrenaline"
---| "inverter"

---@type game.item[]
game.playerInv = {}
---@type game.item[]
game.dealerInv = {}

game.playerHP = 3
game.dealerHP = 3

game.isPlayerTurn = true

game.canPlayerTurn = true
game.canDealerTurn = true
game.gunSawed = false

local function clearShells()
    shells = {}
end

---@return integer # amount of shells
---@return boolean[] # alive and dead shells (true if alive)
local function spawnShells()
    local s = math.random(2, 8)
    local alives = math.random(1, s/2+1)
    if alives == s then alives = alives - 1 end
    for i = 1, alives do
        shells[i] = true
    end
    for i = alives+1, s do
        shells[i] = false
    end
    local shellsCopy = {}
    for i = 1, #shells do
        shellsCopy[i] = shells[i]
    end
    game.initLive = alives
    game.initCount = s
    return s, shellsCopy
end

local function shuffleShells()
    for i = #shells, 2, -1 do
        local j = math.random(i)
        shells[i], shells[j] = shells[j], shells[i]
    end
end

local function shootOther()
    local isAliveShell = table.remove(shells)
    local dmg = game.gunSawed and 2 or 1
    if isAliveShell then
        if game.isPlayerTurn then
            game.dealerHP = game.dealerHP - dmg
        else
            game.playerHP = game.playerHP - dmg
        end
    end
    game.gunSawed = false
    return isAliveShell
end

local function shootSelf()
    local isAliveShell = table.remove(shells)
    local dmg = game.gunSawed and 2 or 1
    if isAliveShell then
        if game.isPlayerTurn then
            game.playerHP = game.playerHP - dmg
        else
            game.dealerHP = game.dealerHP - dmg
        end
    end
    game.gunSawed = false
    return isAliveShell
end

local function giveItems()
    local itemCount = math.random(1, 5)
    ---@type game.item[]
    local items = ({"saw", "handcuffs", "cigarettes", "phone", "magnifying glass", "adrenaline"})
    for i = 1, math.min(itemCount, 8-#game.playerInv) do
        game.playerInv[#game.playerInv+1] = items[math.random(#items)]
    end
    for i = 1, math.min(itemCount, 8-#game.dealerInv) do
        game.dealerInv[#game.dealerInv+1] = items[math.random(#items)]
    end
end

---Returns true if shell was alive
---@return boolean
local function useBeer()
    return table.remove(shells)
end

local function useHandcuffs()
    if game.isPlayerTurn then
        game.canDealerTurn = false
    else
        game.canPlayerTurn = false
    end
end

local function useCigarettes()
    if game.isPlayerTurn then
        game.playerHP = math.min(3, game.playerHP + 1)
    else
        game.dealerHP = math.min(3, game.dealerHP + 1)
    end
end

local function useMagnifyingGlass()
    return shells[#shells]
end

local function usePhone()
    if #shells == 1 then
        return nil, nil
    end
    local r = math.random(#shells-1)
    return #shells-r+1, shells[r]
end

local function useSaw()
    game.gunSawed = true
end

local function useAdrenaline()
    -- this will serve as noop
end

local function useInverter()
    shells[#shells] = not shells[#shells]
end

---@param inv game.item[]
---@param itemName game.item
---@return boolean, ...
local function useItem(inv, itemName)
    -- check if inv has item
    local check = false
    for i, name in ipairs(inv) do
        if name == itemName then
            check = true
            table.remove(inv, i)
            break
        end
    end
    if not check then
        return false, "item not found"
    end

    ---@type table<game.item, function>
    local t = {
        ["beer"] = useBeer,
        ["saw"] = useSaw,
        ["handcuffs"] = useHandcuffs,
        ["cigarettes"] = useCigarettes,
        ["phone"] = usePhone,
        ["magnifying glass"] = useMagnifyingGlass,
        ["adrenaline"] = useAdrenaline,
        ["inverter"] = useInverter,
    }
    local f = t[itemName]
    if not f then
        return false, "item used but no function"
    end
    return true, f()
end

local function strInv(inv, includeback)
    local strs = {}
    if includeback then
        strs[#strs+1] = "0 - go back, "
    end
    for i = 1, #inv do
        strs[#strs+1] = tostring(i)
        strs[#strs+1] = " - "
        strs[#strs+1] = inv[i]
        if i ~= #inv then
            strs[#strs+1] = ", "
        end
    end
    return table.concat(strs)
end

local function switchTurn()
    if game.isPlayerTurn then
        -- was player turn
        if game.canDealerTurn then
            game.isPlayerTurn = false
        else
            game.canDealerTurn = true
        end
    else
        -- was dealer turn
        if game.canPlayerTurn then
            game.isPlayerTurn = true
        else
            game.canPlayerTurn = true
        end
    end
end

local function printUsePlayerItem(item, resb, res1, res2)
    if not resb then
        game.print(resb)
    else
        if item == "beer" then
            game.writeSlow("You drank beer and ejected the shell. ")
            game.printSlow(("It was %s"):format(res1))
        elseif item == "saw" then
            game.write("You sawed the gun.")
            game.print("Next live shot will have double damage.")
        elseif item == "handcuffs" then
            game.printSlow("You handcuffed the Dealer. His next turn will be skipped.")
        elseif item == "cigarettes" then
            game.printSlow("You smoked.")
        elseif item == "phone" then
            local t = {"First", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eight"}
            game.printSlow(("Phone: %s is %s."):format(t[res1], res2 and "live" or "blank"))
        elseif item == "magnifying glass" then
            game.printSlow(("Current shell is... %s."):format(res1 and "live" or "blank"))
        elseif item == "adrenaline" then
            game.printSlow("Steal any of Dealer's items!")
        elseif item == "inverter" then
            game.printSlow("The type of shell has been switched.")
        end
    end
end


-- returns false if to break out of the loop
---@param inv game.item[]
---@param isAdrenaline boolean
---@return boolean
local function askPlayerItemUse(inv, isAdrenaline)
    game.print(("Choose item (%s)"):format(strInv(inv, true)))
    local inputItem = tonumber(read())

    if not inputItem then
        game.print("Invalid. Try Again.")
        return true
    else
        inputItem = math.floor(inputItem)
        if inputItem == 0 then
            return false
        elseif inputItem <= #inv then
            local item = inv[inputItem]
            if item == "adrenaline" and not isAdrenaline then
                local resb, res1, res2 = useItem(inv, item)
                printUsePlayerItem(item, resb, res1, res2)
                while askPlayerItemUse(game.dealerInv, true) do end
            end
            return true
        else
            game.print("Invalid. Try Again.")
            return false
        end
    end
end

local function askPlayerTurn()
    if #game.playerInv > 0 then
        game.print("Choose (0 - shoot self, 1 - shoot the Dealer, 2 - choose item)")
    else
        game.print("Choose (0 - shoot self, 1 - shoot the Dealer)")
    end
    local input = tonumber(read())
    if not input then
        game.print("Invalid. Try Again.")
    else
        if input == 0 then
            local res = shootSelf()
            if res then
                game.printSlow("You shot yourself.")
                switchTurn()
            else
                game.printSlow("It was blank.")
            end
        elseif input == 1 then
            local res = shootOther()
            if res then
                game.printSlow("You shot the Dealer.")
            else
                game.printSlow("It was blank.")
            end
            switchTurn()
        elseif input == 2 and #game.playerInv > 0 then
            while askPlayerItemUse(game.playerInv, false) do end
        else
            game.print("Invalid. Try again.")
        end
    end
end

--- CLI ---

while game.playerHP > 0 and game.dealerHP > 0 do
    -- restart round
    clearShells()
    local c, sh = spawnShells()
    shuffleShells()
    game.print(string.format("Loaded shotgun with %s shells.", c))

    game.print()
    for i = 1, #sh do
        if sh[i] then
            term.blit("\143 ", "ef", "1f")
        else
            term.blit("\143 ", "3f", "1f")
        end
    end
    game.print("\n")

    -- round here
    while #shells > 0 and (game.playerHP > 0 and game.dealerHP > 0) do
        game.print("Lives: P("..string.rep("X", game.playerHP)..") D("..string.rep("X", game.dealerHP)..")")
        game.print("Your inventory: "..strInv(game.playerInv))
        game.print("Dealer inventory: "..strInv(game.dealerInv))
        if game.isPlayerTurn then
            game.print("\n-- Your turn --\n")
            while askPlayerTurn() do end
        else
            game.print("\n-- Dealer's turn --\n")
            -- Dealer turn here. Ask them where they are.
            switchTurn()
        end
    end
    -- round ended, let's give some items
    game.write("Reloading the shotgun")
    game.printSlow("...")
    giveItems()
end

game.print("\n\n  GAME  OVER")
if game.dealerHP > 0 then
    game.print(" DEALER WON.")
else
    game.print(" PLAYER WON.")
end
game.print()