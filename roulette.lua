--- TITLE!!!
local set = settings.get("buccshot", false)
if not set then
    settings.set("buccshot", true)
    term.setTextColor(colors.lightBlue)
    write("BUCCSHOT ROULETTE ")
    term.setTextColor(colors.white)
    print("(PineJam 2026, simadude)")
    print("Original game (Buckshot Roulette) was developed by Mike Klubnika")
    print("The OST from the game is \"General Release\"")
    print("(You will not see this message again until you reboot)\n")
end

--- Audio

local f = fs.open("ost.dfpwm", "rb").readAll()
local arr = require("cc.audio.dfpwm").decode(f)

local s = peripheral.find("speaker") or peripheral.wrap("buccshot_speaker")
if not s and not set then
    print("No speaker Found.")
    if periphemu then
        print("But found periphemu. Do you want to attach custom speaker \"buccshot_speaker\"? [y/n, default=n]")
        local agree = read()
        if agree:lower() == "y" then
            periphemu.create("buccshot_speaker", "speaker")
            s = peripheral.wrap("buccshot_speaker")
        end
    else
        print("Please attach speaker for audio :3")
        sleep(1)
    end
elseif not set then
    print("Press any keys twice to start.")
    os.pullEvent("key")
    os.pullEvent("key")
end
local buf = {}

local function audioLoop()
    while true do
        if not s then
            sleep(0.25)
            s = peripheral.find("speaker")
        else
            for i = 1, #arr, 4000 do
                for j = 1, 4000 do
                    buf[#buf+1] = arr[i+j-1]
                    buf[#buf+1] = arr[i+j-1]
                    buf[#buf+1] = arr[i+j-1]
                    buf[#buf+1] = arr[i+j-1]
                end
                s.playAudio(buf, 0.5)
                os.pullEvent("speaker_audio_empty")
                buf = {}
            end
        end
    end
end

--- Game

local game = {}

function game.print(...)
    print(...)
    sleep(0.20)
end

function game.write(...)
    write(...)
    sleep(0.20)
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

---@param choices string[]
---@return integer
function game.giveChoices(choices)
    local ox, oy = term.getCursorPos()
    local choice = 1
    while true do
        for i = 1, #choices do
            term.setCursorPos(ox, oy+i-1)
            term.setTextColor(i == choice and colors.yellow or colors.white)
            write((i == choice and "> " or "  ")..choices[i])
        end
        term.setTextColor(colors.white)
        local t = {os.pullEvent("key")}
        if t[2] == keys.up then
            choice = math.max(1, choice-1)
        elseif t[2] == keys.down then
            choice = math.min(#choices, choice+1)
        elseif t[2] == keys.enter or t[2] == keys.space then
            print()
            return choice
        end
    end
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
game.playerInv = {"adrenaline"}
---@type game.item[]
game.dealerInv = {"saw", "beer"}

game.playerHP = 2
game.dealerHP = 2
game.maxHP = {2, 4, 6}
game.maxItemsGive = {0, 2, 4}

game.isPlayerTurn = true

game.canPlayerTurn = true
game.canDealerTurn = true
game.gunSawed = false

game.dealerKnownShells = {}
game.dealerKnowsShell = false
game.dealerKnownShell = nil

game.round = 1
game.loadout = 1

function game.clearScreen()
    term.clear()
    term.setCursorPos(1, 1)
    game.print("Round "..tostring(game.round))
    game.print("Lives: P("..string.rep("X", game.playerHP)..") D("..string.rep("X", game.dealerHP)..")")
end

local function clearShells()
    shells = {}
end

---@return integer # amount of shells
---@return boolean[] # alive and dead shells (true if alive)
local function spawnShells()
    local s = math.random(2, 8)
    local alives = math.random(1, s/2+1)
    if game.round == 1 then
        if game.loadout == 1 then
            s = 3
            alives = 1
        elseif game.loadout == 2 then
            s = 5
            alives = 3
        end
    end
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
    for i = 1, #shells do
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
    local itemCount = game.maxItemsGive[game.round] or math.random(2, 5)
    ---@type game.item[]
    local items = ({"saw", "handcuffs", "cigarettes", "phone", "magnifying glass", "adrenaline", "beer", "inverter"})
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
        game.playerHP = math.min(game.maxHP[game.round] or 6, game.playerHP + 1)
    else
        game.dealerHP = math.min(game.maxHP[game.round] or 6, game.dealerHP + 1)
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

local function dealerFigureOutShell()
    if game.dealerKnownShells[#shells] then
        return true
    end

    local liveCount = 0
    local blankCount = 0
    for i = 1, #shells do
        if shells[i] then liveCount = liveCount + 1 else blankCount = blankCount + 1 end
    end

    if liveCount == 0 or blankCount == 0 then
        return true
    end

    for i = 1, #shells do
        if game.dealerKnownShells[i] then
            if shells[i] then liveCount = liveCount - 1 else blankCount = blankCount - 1 end
        end
    end

    if liveCount == 0 or blankCount == 0 then
        return true
    end

    return false
end

local function dealerHasItem(itemName)
    for _, item in ipairs(game.dealerInv) do
        if item == itemName then return true end
    end
    return false
end

local function dealerTurn()
    game.printSlow("Dealer is thinking...")

    if #shells == 0 then
        switchTurn()
        return
    end

    game.dealerTarget = nil

    if #shells == 1 then
        game.dealerKnowsShell = true
        game.dealerKnownShell = shells[#shells] and "live" or "blank"
    elseif not game.dealerKnowsShell then
        game.dealerKnowsShell = dealerFigureOutShell()
        if game.dealerKnowsShell then
            game.dealerKnownShell = shells[#shells] and "live" or "blank"
        end
    end

    if game.dealerKnowsShell then
        game.dealerTarget = game.dealerKnownShell == "live" and "player" or "self"
    end

    while true do
        local itemToUse = nil

        for _, item in ipairs(game.dealerInv) do
            if item == "magnifying glass" and not game.dealerKnowsShell and #shells ~= 1 then
                itemToUse = "magnifying glass"
                break
            end
            if item == "cigarettes" and game.dealerHP < 3 then
                itemToUse = "cigarettes"
                break
            end
            if item == "beer" and game.dealerKnownShell ~= "live" and #shells ~= 1 then
                itemToUse = "beer"
                break
            end
            if item == "handcuffs" and game.canPlayerTurn and #shells ~= 1 then
                itemToUse = "handcuffs"
                break
            end
            if item == "saw" and not game.gunSawed and game.dealerKnownShell == "live" then
                itemToUse = "saw"
                break
            end
            if item == "phone" and #shells > 2 then
                itemToUse = "phone"
                break
            end
            if item == "inverter" and game.dealerKnowsShell and game.dealerKnownShell == "blank" then
                itemToUse = "inverter"
                break
            end
        end

        if not itemToUse then break end

        local resb, res1 = useItem(game.dealerInv, itemToUse)
        game.writeSlow("Dealer uses " .. itemToUse .. ".")

        if itemToUse == "magnifying glass" then
            game.dealerKnowsShell = true
            game.dealerKnownShell = shells[#shells] and "live" or "blank"
            game.dealerTarget = game.dealerKnownShell == "live" and "player" or "self"
        elseif itemToUse == "beer" then
            game.dealerKnowsShell = false
            game.dealerKnownShell = nil
            game.dealerTarget = nil
            game.writeSlow("The shell was "..(res1 and "live" or "blank"))
        elseif itemToUse == "phone" then
            local idx = #shells - res1 + 1
            game.dealerKnownShells[idx] = true
            game.write("Dealer: ")
            game.printSlow("Interesting...")
        elseif itemToUse == "inverter" then
            game.dealerKnownShell = "live"
            game.dealerKnowsShell = true
            game.dealerTarget = "player"
        end
    end

    if dealerHasItem("saw") and not game.gunSawed and game.dealerKnownShell ~= "blank" then
        local coin = math.random(0, 1)
        if coin == 0 then
            game.dealerTarget = "self"
        else
            useItem(game.dealerInv, "saw")
            game.dealerTarget = "player"
            game.gunSawed = true
            game.writeSlow("Dealer uses saw.")
        end
    end

    if not game.dealerTarget then
        local coin = math.random(0, 1)
        game.dealerTarget = (coin == 0) and "self" or "player"
    end

    local goAgain = false
    if game.dealerTarget == "self" then
        local res = shootSelf()
        if res then
            game.printSlow("Dealer shot himself.")
        else
            game.printSlow("Dealer shot himself. It was blank.")
            goAgain = true
        end
    else
        local res = shootOther()
        if res then
            game.printSlow("Dealer shot you!")
        else
            game.printSlow("Dealer shot you. It was blank.")
        end
    end

    game.dealerKnowsShell = false
    game.dealerKnownShell = nil
    game.dealerTarget = nil

    if not goAgain then
        switchTurn()
    end
end

local function printUsePlayerItem(item, resb, res1, res2)
    if not resb then
        game.print(resb)
    else
        if item == "beer" then
            game.writeSlow("You drank beer and ejected the shell. ")
            game.printSlow(("It was %s"):format(res1 and "live" or "blank"))
        elseif item == "saw" then
            game.write("You sawed the gun. ")
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
    if #inv == 0 then
        return false
    end
    local choices = {"Go Back"}
    for _, item in ipairs(inv) do
        choices[#choices + 1] = item
    end
    local input = game.giveChoices(choices)
    if input == 1 then
        return false
    end

    local item = inv[input - 1]
    if item == "adrenaline" and not isAdrenaline then
        local resb, res1, res2 = useItem(inv, item)
        printUsePlayerItem(item, resb, res1, res2)
        while askPlayerItemUse(game.dealerInv, true) do end
    elseif isAdrenaline then
        local resb, res1, res2 = useItem(inv, item)
        printUsePlayerItem(item, resb, res1, res2)
        return false
    else
        local resb, res1, res2 = useItem(inv, item)
        printUsePlayerItem(item, resb, res1, res2)
    end
    return true
end

local function askPlayerTurn()
    local choices = {"Shoot Self", "Shoot the Dealer"}
    if #game.playerInv > 0 then
        choices[#choices + 1] = "Choose Item"
    end
    local input = game.giveChoices(choices)
    if input == 1 then
        local res = shootSelf()
        if res then
            game.printSlow("You shot yourself.")
            switchTurn()
        else
            game.printSlow("It was blank.")
        end
    elseif input == 2 then
        local res = shootOther()
        if res then
            game.printSlow("You shot the Dealer.")
        else
            game.printSlow("It was blank.")
        end
        switchTurn()
    elseif input == 3 then
        while askPlayerItemUse(game.playerInv, false) do end
    end
end

--- CLI ---
local function gameLoop()
    while true do
        if game.round > 3 then
            break
        end
        game.clearScreen()
        if game.round > 1 then
            giveItems()
        end
        while game.playerHP > 0 and game.dealerHP > 0 do
            -- new loadout
            game.write("Reloading the shotgun")
            game.printSlow("...")

            clearShells()
            game.dealerKnownShells = {}
            game.dealerKnowsShell = false
            game.dealerKnownShell = nil
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

            while #shells > 0 and (game.playerHP > 0 and game.dealerHP > 0) do
                game.print("Your inventory: "..strInv(game.playerInv))
                game.print("Dealer inventory: "..strInv(game.dealerInv))
                if game.isPlayerTurn then
                    game.print("\n-- Your turn --\n")
                    while askPlayerTurn() do end
                else
                    game.print("\n-- Dealer's turn --\n")
                    dealerTurn()
                    sleep(0.5)
                end
                game.clearScreen()
            end
            game.loadout = game.loadout + 1
        end
        if game.playerHP <= 0 then
            break
        elseif game.round <= 3 then
            -- so playerhp > 0 and game.round <= 3, but dealerhp == 0
            game.round = game.round + 1
            game.playerHP = game.maxHP[game.round]
            game.dealerHP = game.maxHP[game.round]
        end
    end

    game.print("\n\n  GAME  OVER")
    if game.dealerHP > 0 then
        game.print(" DEALER WON.\n")
    else
        game.print(" PLAYER WON.\n")
    end
end

parallel.waitForAny(gameLoop, audioLoop)