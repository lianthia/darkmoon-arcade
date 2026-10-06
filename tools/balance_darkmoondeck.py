"""Plays Darkmoon Deck runs with a simple bot to tune the goals: python tools/balance_darkmoondeck.py"""
import pathlib
import sys

from lupa import luajit21 as lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 300

lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute("ns = {}")
loader = lua.eval("function(code) local f = assert(loadstring(code)); f('DarkmoonArcade', ns) end")
loader((ROOT / "DarkmoonArcade/Games/DarkmoonDeck/Game.lua").read_text(encoding="utf-8"))

result = lua.execute("""
local Game = ns.DarkmoonDeck.Game
local runs = ...
math.randomseed(7)
local antes, scores, best = {}, 0, 0
for _ = 1, runs do
    local g = Game.New()
    g:StartRun()
    local guard = 0
    while (g.state == "PLAYING" or g.state == "SHOP") and guard < 400 do
        guard = guard + 1
        if g.state == "SHOP" then
            -- Buys whatever it can afford, cheapest first.
            for slot = 1, 3 do
                local offer = g.offers[slot]
                if offer and g.gold >= offer.price then g:Buy(slot) end
            end
            g:NextRound()
        else
            local indexes, value = g:BestPlay()
            local need = (g.goal - g.roundScore) / math.max(1, g.plays)
            if value < need * 0.6 and g.discards > 0 then
                -- Keeps the best cards, throws away the rest.
                local keep = {}
                for _, i in ipairs(indexes) do keep[i] = true end
                local throw = {}
                for i = 1, #g.hand do if not keep[i] and #throw < 5 then throw[#throw + 1] = i end end
                if #throw == 0 then g:Play(indexes) else g:Discard(throw) end
            else
                g:Play(indexes)
            end
        end
    end
    local reached = g.state == "WON" and 9 or g.ante
    antes[reached] = (antes[reached] or 0) + 1
    scores = scores + g.score
    best = math.max(best, g.bestHand)
end
local out = {}
for a = 1, 9 do out[#out + 1] = (a == 9 and "won" or ("ante " .. a)) .. ": " .. (antes[a] or 0) end
return table.concat(out, ", ") .. (" | avg score %d, best hand %d"):format(scores / runs, best)
""", RUNS)
print(result)
