"""Plays Mercenaries bounties with a bot to check the balance: python tools/balance_mercenaries.py [runs]

For every zone the starting party runs the bounty at fixed levels relative to the zone. The
acceptance criteria from the concept:
  - 5 levels below the zone's minimum: boss beaten in under 1 % of runs
  - 10 levels below: under 0.1 %
  - a fitting party (boss level - 1): 50-70 %
Use `--progress` to simulate a new player levelling through all zones instead, and `--gap` for a
single regular fight against foes above the party's level (how much a level gap matters).

Progress profiles (`--profile fresh|items|geared|full`, concept docs/konzept-dungeons.md, section 7):
  fresh   no ranks, no items (a new player; the bounty criteria above use it)
  items   no ranks, rare dungeon items of an average kind and about the party's level in every open
          slot, no enchants
  geared  ranks III with the first ability at rank IV, the items of "items", enchants of tier 2-3
  full    every ability at rank IV, the best epic items, enchants of the highest tier
Further reports:
  --items     a full set of rare items alone: at most about +5 points of win rate on bounties
  --dungeons  every dungeon at boss level - 1: normal 40-55 % in the profile "fresh"
  --heroic    bounties and dungeons at level 60: about 40 % "geared", clearly less "fresh"
`--tune --dungeons` and `--tune --heroic` find each zone's `power` / `heroicPower` for these targets.
"""
import pathlib
import sys

from lupa import luajit21 as lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "DarkmoonArcade"
FILES = ["Combat", "Abilities", "Mercs", "Treasures", "Enemies", "Zones", "Bounty", "ItemData", "Items",
         "Enchanting", "Quests", "Dungeons"]

args = [a for a in sys.argv[1:] if a.isdigit()]
RUNS = int(args[0]) if args else 200
PROGRESS = "--progress" in sys.argv
SWEEP = "--sweep" in sys.argv
TUNE = "--tune" in sys.argv
DUNGEONS = "--dungeons" in sys.argv
HEROIC = "--heroic" in sys.argv
PROFILE = sys.argv[sys.argv.index("--profile") + 1] if "--profile" in sys.argv else "fresh"
TARGET = 0.6
# Dungeons: normal at boss level - 1 in the profile "fresh"; heroic at level 60 in the profile "geared".
DUNGEON_TARGET, DUNGEON_RANGE = 0.47, (0.4, 0.55)
HEROIC_TARGET, HEROIC_RANGE = 0.4, (0.35, 0.45)
# --planner: the bot plays like the debug mode's "Play all turns" (best orders found by simulation).
USE_PLANNER = "--planner" in sys.argv

lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.execute("ns = { AddStrings = function() end }")
loader = lua.eval("function(code, name) local f = assert(loadstring(code, name)); f('DarkmoonArcade', ns) end")
for name in FILES:
    loader((ADDON / "Games" / "Mercenaries" / f"{name}.lua").read_text(encoding="utf-8"), name)

lua.globals().PLANNER = USE_PLANNER
lua.globals().PROFILE = PROFILE
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
    store.pendingItems = nil
    return run.phase == "complete", run.fights
end

-- What each role looks for in an item: the bonuses that help it in a fight, by weight.
local WANTS = {
    protector = { hpPct = 1, takenPct = 1, regenPct = 0.5, atkPct = 0.3 },
    fighter = { atkPct = 1, critChance = 1, hpPct = 0.3 },
    caster = { spellPct = 1, critChance = 0.7, hpPct = 0.3 },
}
local function Fit(role, mods)
    local sum = 0
    for k, v in pairs(mods) do sum = sum + (WANTS[role][k] or 0) * v end
    return sum
end

-- The item a profile wears in a slot: "best" the strongest for the role, "average" the median of
-- those that suit it at all, of the levels least..most.
local function PickItem(role, kind, rarity, least, most, how)
    local list = {}
    for id, item in pairs(MC.Items) do
        if item.kind == kind and item.rarity == rarity and item.level >= least and item.level <= most then
            local fit = Fit(role, item.points)
            if fit > 0 then list[#list + 1] = { id = id, fit = fit } end
        end
    end
    table.sort(list, function(a, b) if a.fit ~= b.fit then return a.fit < b.fit end return a.id < b.id end)
    if #list == 0 then return nil end
    if how == "best" then return list[#list].id end
    return list[math.floor((#list + 1) / 2)].id
end

-- The strongest formula of the tiers that fits the item and suits the role.
local function PickRecipe(role, item, lo, hi)
    local best, bestFit
    for id, recipe in pairs(MC.Recipes) do
        if recipe.tier >= lo and recipe.tier <= hi and MC.RecipeFits(recipe, item) then
            local fit = Fit(role, MC.RecipeMods(recipe))
            if fit > 0 and (not bestFit or fit > bestFit or (fit == bestFit and id < best)) then best, bestFit = id, fit end
        end
    end
    return best
end

-- Ranks, items and enchants of a progress profile (see the file's head).
function ApplyProfile(store, profile)
    if profile == "fresh" then return end
    for id, entry in pairs(store.mercs) do
        if entry.owned then
            local role = MC.Mercs[id].role
            if profile == "geared" then entry.ranks = { 4, 3, 3 }
            elseif profile == "full" then entry.ranks = { 4, 4, 4 } end
            local full = profile == "full"
            entry.items, entry.worn, entry.enchants = {}, {}, {}
            for slot = 1, MC.ItemSlots(entry) do
                -- Items of about the mercenary's level (they drop in the dungeons of its levels).
                local itemId = PickItem(role, MC.ITEM_SLOT_KINDS[slot], full and "epic" or "rare",
                    entry.level - (full and 5 or 12), full and 99 or entry.level + 2, full and "best" or "average")
                if itemId then
                    entry.items[#entry.items + 1] = itemId
                    entry.worn[slot] = itemId
                    if profile ~= "items" then
                        entry.enchants[itemId] = PickRecipe(role, MC.Items[itemId], full and 4 or 2, full and 4 or 3)
                    end
                end
            end
        end
    end
end

function FixedStore(level, profile)
    local store = {}
    Bounty.Init(store)
    for _, id in ipairs(store.party) do store.mercs[id].level = level end
    ApplyProfile(store, profile or "fresh")
    return store
end

local addXP = Bounty.AddXP
function FreezeLevels(frozen)
    Bounty.AddXP = frozen and function() return 0 end or addXP
end

function WinRate(zone, level, heroic, runs, profile)
    FreezeLevels(true)
    local wins, fights = 0, 0
    for seed = 1, runs do
        local store = FixedStore(level, profile or PROFILE)
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
dungeons = [MC.DUNGEON_ORDER[i] for i in range(1, len(MC.DUNGEON_ORDER) + 1)]
# --zone a,b,c: only these zones and dungeons (several processes can tune in parallel).
only = sys.argv[sys.argv.index("--zone") + 1].split(",") if "--zone" in sys.argv else None
if only:
    order = [z for z in order if z in only]
    dungeons = [z for z in dungeons if z in only]

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
    # Finds each zone's `power`: bounties 60 % at boss level - 1 ("fresh"), dungeons 47 % there,
    # heroic 40 % at level 60 for a geared party (bounties and dungeons, or only dungeons with --dungeons).
    bounty = MC.Bounty
    profile = "geared" if HEROIC else PROFILE
    target = HEROIC_TARGET if HEROIC else DUNGEON_TARGET if DUNGEONS else TARGET
    zones = dungeons if DUNGEONS else order + (dungeons if HEROIC else [])
    key = "heroicPower" if HEROIC else "power"
    found = {}
    for zid in zones:
        zone = MC.Zones[zid]
        level = 60 if HEROIC else bounty.BossLevel(zone, False) - 1
        lo, hi = -0.8, 3.5
        for _ in range(9):
            mid = (lo + hi) / 2
            zone[key] = mid
            rate = g.WinRate(zid, level, HEROIC, RUNS, profile)[0]
            if rate > target:
                lo = mid
            else:
                hi = mid
        zone[key] = round((lo + hi) / 2, 2)
        rate = g.WinRate(zid, level, HEROIC, RUNS, profile)[0]
        found[zid] = zone[key]
        print(f"{zid:15} {key} = {zone[key]:5.2f}  -> {rate * 100:.0f}%", flush=True)
    print("TUNED", key, found)
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

if HEROIC:
    # Heroic at level 60: about 40 % for a geared party, clearly less for a fresh one.
    print(f"{'zone':15} {'fresh':>7} {'geared':>7} {'full':>7}")
    failures = []
    for zid in (dungeons if DUNGEONS else order + dungeons):
        rates = [g.WinRate(zid, 60, True, RUNS, p)[0] for p in ("fresh", "geared", "full")]
        print(f"{zid:15} " + " ".join(f"{r * 100:6.1f}%" for r in rates), flush=True)
        if not HEROIC_RANGE[0] <= rates[1] <= HEROIC_RANGE[1]:
            failures.append(f"{zid}: {rates[1]:.0%} heroic geared (want 35-45 %)")
        if rates[0] > rates[1] - 0.15:
            failures.append(f"{zid}: fresh {rates[0]:.0%} not clearly below geared")
    print("\n".join(failures) if failures else "all heroic criteria met")
    sys.exit(1 if failures else 0)

if DUNGEONS:
    # Normal dungeons at boss level - 1: 40-55 % fresh; and what items and ranks add.
    print(f"{'dungeon':15} {'boss':>4} {'-5':>7} {'fresh':>7} {'items':>7} {'geared':>7}")
    failures = []
    for zid in dungeons:
        zone = MC.Zones[zid]
        boss = MC.Bounty.BossLevel(zone, False)
        low = g.WinRate(zid, max(1, zone.min - 5), False, RUNS, "fresh")[0]
        rates = [g.WinRate(zid, boss - 1, False, RUNS, p)[0] for p in ("fresh", "items", "geared")]
        print(f"{zid:15} {boss:4} {low * 100:6.1f}% " + " ".join(f"{r * 100:6.1f}%" for r in rates), flush=True)
        if not DUNGEON_RANGE[0] <= rates[0] <= DUNGEON_RANGE[1]:
            failures.append(f"{zid}: {rates[0]:.0%} at boss-1 (want 40-55 %)")
        if low > 0.01:
            failures.append(f"{zid}: {low:.1%} at -5")
    print("\n".join(failures) if failures else "all dungeon criteria met")
    sys.exit(1 if failures else 0)

if "--items" in sys.argv:
    # A full set of average rare items without ranks against bounties at boss level - 1.
    print(f"{'zone':12} {'fresh':>7} {'items':>7} {'diff':>6}")
    gains = []
    for zid in order:
        boss = MC.Bounty.BossLevel(MC.Zones[zid], False)
        a = g.WinRate(zid, boss - 1, False, RUNS, "fresh")[0]
        b = g.WinRate(zid, boss - 1, False, RUNS, "items")[0]
        # Below level 20 the first rare items are rare indeed; zones without any are left out.
        if b != a:
            gains.append(b - a)
        print(f"{zid:12} {a * 100:6.1f}% {b * 100:6.1f}% {(b - a) * 100:+5.1f}", flush=True)
    mean = sum(gains) / max(1, len(gains))
    print(f"mean gain {mean * 100:+.1f} points (want about +5), largest {max(gains, default=0) * 100:+.1f}")
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
