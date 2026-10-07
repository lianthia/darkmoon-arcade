"""Plays Mercenaries bounties with a bot to check the balance: python tools/balance_mercenaries.py [runs]

For every zone the starting party runs the bounty at fixed levels relative to the zone. The
acceptance criteria from the concept:
  - 5 levels below the zone's minimum: boss beaten in under 1 % of runs
  - 10 levels below: under 0.1 %
  - a fitting party (boss level - 1): 50-70 %
Use `--progress` to simulate a new player levelling through all zones instead.
"""
import pathlib
import sys

from lupa import luajit21 as lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "DarkmoonArcade"
FILES = ["Combat", "Abilities", "Mercs", "Treasures", "Enemies", "Zones", "Bounty"]

args = [a for a in sys.argv[1:] if a.isdigit()]
RUNS = int(args[0]) if args else 200
PROGRESS = "--progress" in sys.argv
SWEEP = "--sweep" in sys.argv
TUNE = "--tune" in sys.argv
TARGET = 0.6

lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute("ns = {}")
loader = lua.eval("function(code, name) local f = assert(loadstring(code, name)); f('DarkmoonArcade', ns) end")
for name in FILES:
    loader((ADDON / "Games" / "Mercenaries" / f"{name}.lua").read_text(encoding="utf-8"), name)

lua.execute("""
local MC = ns.Mercenaries
local Combat, Bounty = MC.Combat, MC.Bounty

-- Deploys the healthiest mercenaries first and fights like the enemy AI does.
function AutoBattle(b)
    local guard = 0
    while (b.phase == "deploy" or b.phase == "replace" or b.phase == "command") and guard < 300 do
        guard = guard + 1
        if b.phase == "command" then
            Combat.AutoChoose(b)
            Combat.Resolve(b)
        else
            Combat.Deploy(b, b.bench.ally[1])
        end
    end
    return b.phase
end

-- One bounty; returns true when the boss fell, and the number of fights won.
function PlayRun(store, zone, heroic, seed)
    local run = Bounty.NewRun(store, zone, heroic, seed)
    local guard = 0
    while guard < 400 do
        guard = guard + 1
        local phase = run.phase
        if phase == "map" then
            local choices = Bounty.Choices(run)
            local pick = choices[(seed + guard) % #choices + 1]
            Bounty.Travel(store, run, pick.layer, pick.index)
        elseif phase == "battle" then
            AutoBattle(run.battle)
            Bounty.AfterBattle(store, run)
        elseif phase == "treasure" then
            Bounty.ChooseTreasure(store, run, run.offer.kind == "cursed" and nil or 1)
        elseif phase == "healer" then
            Bounty.Revive(run, Bounty.DeadMembers(run)[1])
        elseif phase == "stranger" then
            Bounty.Stranger(run, 1)
        else
            break
        end
    end
    store.run = nil
    return run.phase == "complete", run.fights
end

function FixedStore(level)
    local store = {}
    Bounty.Init(store)
    for _, id in ipairs(store.party) do store.mercs[id].level = level end
    return store
end

local addXP = Bounty.AddXP
function FreezeLevels(frozen)
    Bounty.AddXP = frozen and function() return 0 end or addXP
end

function WinRate(zone, level, heroic, runs)
    FreezeLevels(true)
    local wins, fights = 0, 0
    for seed = 1, runs do
        local store = FixedStore(level)
        if heroic then Bounty.ZoneState(store, zone).normal = 1 end
        local won, f = PlayRun(store, zone, heroic, seed * 7919)
        if won then wins = wins + 1 end
        fights = fights + f
    end
    FreezeLevels(false)
    return wins / runs, fights / runs
end

-- A fresh player: always picks the lowest zone not yet cleared, retries on defeat.
function Progress(maxRuns)
    local store = {}
    Bounty.Init(store)
    local log, runs = {}, 0
    for _, zid in ipairs(MC.ZONE_ORDER) do
        local tries = 0
        while Bounty.ZoneState(store, zid).normal == 0 and runs < maxRuns do
            runs, tries = runs + 1, tries + 1
            PlayRun(store, zid, false, runs * 104729)
        end
        log[#log + 1] = { zid, tries, Bounty.PartyLevel(store) }
    end
    return log, runs
end
""")

g = lua.globals()
MC = g.ns.Mercenaries
order = [MC.ZONE_ORDER[i] for i in range(1, len(MC.ZONE_ORDER) + 1)]

if SWEEP:
    # Tries enemy and boss strengths on a few zones at boss level - 1.
    bounty = MC.Bounty
    sample = ["elwynn", "westfall", "barrens", "duskwood", "hillsbrad"]
    for e_hp, e_atk, b_hp, b_atk in [(a, b, c, d) for a in (0.3, 0.6) for b in (0.2, 0.4) for c in (0.3, 0.8) for d in (0.2, 0.5)]:
        bounty.ENEMY_MODS.hpPct, bounty.ENEMY_MODS.atkPct = e_hp, e_atk
        bounty.BOSS_MODS.hpPct, bounty.BOSS_MODS.atkPct = b_hp, b_atk
        rates = []
        for zid in sample:
            boss = bounty.BossLevel(MC.Zones[zid], False)
            rates.append(g.WinRate(zid, boss - 1, False, RUNS)[0])
        print(f"enemy hp {e_hp:.1f} atk {e_atk:.1f}  boss hp {b_hp:.1f} atk {b_atk:.1f}: "
              + " ".join(f"{r * 100:4.0f}" for r in rates) + f"  mean {sum(rates) / len(rates) * 100:.0f}%")
    sys.exit(0)

if TUNE:
    # Finds each zone's `power` so the bot beats the boss in about 60 % of runs at boss level - 1
    # (heroic: 40 % at level 59).
    bounty = MC.Bounty
    heroic = "--heroic" in sys.argv
    # Heroic is the endgame: the bot plays without ranks or gear, so it should lose more often.
    if heroic:
        TARGET = 0.4
    only = sys.argv[sys.argv.index("--zone") + 1] if "--zone" in sys.argv else None
    for zid in order:
        if only and zid != only:
            continue
        zone = MC.Zones[zid]
        level = 59 if heroic else bounty.BossLevel(zone, False) - 1
        key = "heroicPower" if heroic else "power"
        lo, hi = -0.8, 2.5
        for _ in range(9):
            mid = (lo + hi) / 2
            zone[key] = mid
            rate = g.WinRate(zid, level, heroic, RUNS)[0]
            if rate > TARGET:
                lo = mid
            else:
                hi = mid
        zone[key] = round((lo + hi) / 2, 2)
        rate = g.WinRate(zid, level, heroic, RUNS)[0]
        print(f"{zid:12} {key} = {zone[key]:5.2f}  -> {rate * 100:.0f}%")
    sys.exit(0)

if PROGRESS:
    log, runs = g.Progress(2000)
    for i in range(1, len(log) + 1):
        zid, tries, level = log[i][1], log[i][2], log[i][3]
        print(f"{zid:12} cleared after {tries:3} runs, party level {level:5.1f}")
    print("total runs:", runs)
    sys.exit(0)

print(f"{'zone':12} {'boss':>4} {'-10':>7} {'-5':>7} {'boss-3':>7} {'boss-1':>7} {'boss+2':>7}  fights@boss-1")
failures = []
for zid in order:
    zone = MC.Zones[zid]
    boss = MC.Bounty.BossLevel(zone, False)
    cells = []
    for label, level in (("-10", zone.min - 10), ("-5", zone.min - 5), ("boss-3", boss - 3),
                         ("boss-1", boss - 1), ("boss+2", boss + 2)):
        if level < 1:
            cells.append(("—", None, 0))
            continue
        rate, fights = g.WinRate(zid, level, False, RUNS)
        cells.append((f"{rate * 100:6.1f}%", rate, fights))
        if label == "-10" and rate > 0.001:
            failures.append(f"{zid}: {rate:.2%} at -10")
        if label == "-5" and rate > 0.01:
            failures.append(f"{zid}: {rate:.2%} at -5")
        if label == "boss-1" and not 0.5 <= rate <= 0.7:
            failures.append(f"{zid}: {rate:.0%} at boss-1 (want 50-70 %)")
    print(f"{zid:12} {boss:4} " + " ".join(f"{c[0]:>7}" for c in cells) + f"  {cells[3][2]:.1f}")

heroic_rate, _ = g.WinRate("elwynn", 60, True, RUNS)
print(f"heroic Elwynn at level 60: {heroic_rate:.0%}")
print("\nall criteria met" if not failures else "\n" + "\n".join(failures))
