"""Simulates Goblin Slot Machine runs with simple pick strategies: python tools/balance_goblinslots.py"""
import pathlib

from lupa import luajit21 as lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent
SIM = r'''
local Game = ns.GoblinSlots.Game
local rank = { legendary = 4, rare = 3, uncommon = 2, common = 1 }
local function run(seed, strategy)
    local s = seed
    local game = Game.New(function(n) s = (s * 16807) % 2147483647; return s % n + 1 end)
    game:Start()
    while game.state ~= "OVER" and game.rentsPaid < 40 do
        game:Spin()
        local pick = game.offer[1]
        if strategy == "rarest" then
            for _, id in ipairs(game.offer) do
                if rank[Game.SYMBOLS[id].rarity] > rank[Game.SYMBOLS[pick].rarity] then pick = id end
            end
        elseif strategy == "skip" then
            pick = nil
        end
        game:Pick(pick)
    end
    return game.rentsPaid, game.earned
end
local lines = {}
for _, strategy in ipairs({ "first", "rarest", "skip" }) do
    local total, best, earned = 0, 0, 0
    for seed = 1, 300 do
        local r, e = run(seed * 13, strategy)
        total, best, earned = total + r, math.max(best, r), earned + e
    end
    lines[#lines + 1] = ("%-7s avg rents %.1f, best %d, avg gold %d"):format(strategy, total / 300, best, earned / 300)
end
return table.concat(lines, "\n")
'''


def main():
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute("ns = {}")
    loader = lua.eval("function(code) assert(loadstring(code))('DarkmoonArcade', ns) end")
    loader((ROOT / "DarkmoonArcade/Games/GoblinSlots/Game.lua").read_text(encoding="utf-8"))
    print(lua.execute(SIM))


if __name__ == "__main__":
    main()
