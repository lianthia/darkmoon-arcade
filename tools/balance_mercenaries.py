"""Plays Mercenaries bounties with a bot to check the balance: python tools/balance_mercenaries.py [runs]

For every zone the starting party runs the bounty at fixed levels relative to the zone. The
acceptance criteria from the concept:
  - 5 levels below the zone's minimum: boss beaten in under 1 % of runs
  - 10 levels below: under 0.1 %
  - a fitting party (boss level - 1): 50-70 %
Use `--progress` to simulate a new player levelling through all zones instead, and `--gap` for a
single regular fight against foes above the party's level (how much a level gap matters).
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
# --planner: the bot plays like the debug mode's "Play all turns" (best orders found by simulation).
USE_PLANNER = "--planner" in sys.argv

lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute("ns = {}")
loader = lua.eval("function(code, name) local f = assert(loadstring(code, name)); f('DarkmoonArcade', ns) end")
for name in FILES:
    loader((ADDON / "Games" / "Mercenaries" / f"{name}.lua").read_text(encoding="utf-8"), name)

lua.globals().PLANNER = USE_PLANNER
lua.execute("""
local MC = ns.Mercenaries
local Combat, Bounty = MC.Combat, MC.Bounty

-- Deploys the healthiest mercenaries first and fights like the enemy AI does.
function AutoBattle(b)
    local guard = 0
    while (b.phase == "deploy" or b.phase == "replace" or b.phase == "command") and guard < 300 do
        guard = guard + 1
        if b.phase == "command" then
            if PLANNER then Combat.BestChoices(b) else Combat.AutoChoose(b) end
            Combat.Resolve(b)
        else
            local pick = PLANNER and Combat.BestReplacement(b)
            Combat.Deploy(b, pick and pick.uid or b.bench.ally[1])
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

-- One regular fight of three of the zone's foes at `foeLevel`, the starting party at `partyLevel`
-- (no treasures, ranks or gear). Returns the share of fights won.
function GapRate(zid, partyLevel, foeLevel, runs)
    local zone = MC.Zones[zid]
    local wins = 0
    for seed = 1, runs do
        local store = FixedStore(partyLevel)
        local run = Bounty.NewRun(store, zid, false, seed * 7919)
        local allies = {}
        for idx, member in ipairs(run.party) do
            local spec = Bounty.MercSpec(store, member.id, member, run)
            spec.pidx = idx
            allies[#allies + 1] = spec
        end
        local enemies = {}
        for i = 1, 3 do
            local id = zone.pool[(seed * 31 + i * 7) % #zone.pool + 1]
            enemies[i] = Bounty.EnemySpec(id, foeLevel, { power = zone.power })
        end
        local b = Combat.New(allies, enemies, seed * 104729)
        AutoBattle(b)
        if b.phase == "won" then wins = wins + 1 end
        store.run = nil
    end
    return wins / runs
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
# --gapparams miss,missSq,dmg,bonus,bonusCap: try other level-gap values without editing Combat.lua.
if "--gapparams" in sys.argv:
    values = [float(v) for v in sys.argv[sys.argv.index("--gapparams") + 1].split(",")]
    for key, value in zip(["miss", "missSq", "dmg", "bonus", "bonusCap"], values):
        MC.Combat.GAP[key] = value
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

if "--gap" in sys.argv:
    # A party below its foes: party level = foe level - gap, for foes at each zone's boss level - 3.
    gaps = [0, 1, 2, 3, 4, 5, 6]
    print(f"{'zone':12} {'foes':>4} " + " ".join(f"{('-' + str(g)):>6}" for g in gaps))
    for zid in ["westfall", "redridge", "duskwood", "hillsbrad", "arathi", "stranglethorn", "tanaris", "felwood"]:
        zone = MC.Zones[zid]
        foe = MC.Bounty.BossLevel(zone, False) - 3
        rates = [g.GapRate(zid, foe - gap, foe, RUNS) for gap in gaps]
        print(f"{zid:12} {foe:4} " + " ".join(f"{r * 100:5.0f}%" for r in rates))
    sys.exit(0)

if PROGRESS:
    log, runs = g.Progress(2000)
    for i in range(1, len(log) + 1):
        zid, tries, level = log[i][1], log[i][2], log[i][3]
        print(f"{zid:12} cleared after {tries:3} runs, party level {level:5.1f}")
    print("total runs:", runs)
    sys.exit(0)

if "--heroic" in sys.argv:
    # Heroic report: the bot at level 59 and 60 without ranks or gear; tuned for about 40 % at 59.
    print(f"{'zone':12} {'59':>7} {'60':>7}")
    failures = []
    for zid in order:
        r59 = g.WinRate(zid, 59, True, RUNS)[0]
        r60 = g.WinRate(zid, 60, True, RUNS)[0]
        print(f"{zid:12} {r59 * 100:6.1f}% {r60 * 100:6.1f}%")
        if not 0.3 <= r59 <= 0.5:
            failures.append(f"{zid}: {r59:.0%} heroic at 59 (want 30-50 %)")
    print("\n".join(failures) if failures else "all heroic criteria met")
    sys.exit(1 if failures else 0)

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
