# Core Game Design: 16-bit Turn-Based RPG with Soulslike Combat

Date: 2026-11-25
Status: Draft for review
Working title: TBD (story and setting come later)

Notes on this document: anything the creator decided is stated as a decision. Anything the builder (Claude) filled in is marked **[builder's call]** and can be changed.

---

## 1. Intent

This is a personal project. There is no deadline, no commercial target and no market to please. Success means the creator enjoys building it and playing it, and the first playable version arrives quickly enough to keep the project alive.

The game combines two feelings:

- **From turn-based RPGs:** a rich story, a calm pace and time to think.
- **From soulslikes:** fights that keep you alert, bosses you learn and beat through skill, and the "who's next?" pull after every victory.

The rhythm of play is **calm, then tense, then calm**. Exploration and story are the breather. Boss fights are the peaks.

## 2. Goals, non-goals, anti-goals

**Goals**
- Combat where the player stays engaged during both their own turn and the enemy's turn.
- Bosses that are memorable, readable and learnable, where winning feels earned through skill.
- A losing experience that keeps challenge-seekers challenged but never makes a stuck player quit.
- A scope small enough to finish.

**Non-goals (for now)**
- Story, setting, characters' identities and world. These are decided later.
- Final art. Placeholder art comes first.
- Commercial release, store pages, localization and console ports.

**Anti-goals (this would be a failure even if it technically works)**
- Combat that becomes menu-picking while you watch animations. That is the thing this game exists to avoid.
- Timing windows that feel unfair or unreadable. Soulslike difficulty must come from learnable patterns, not cheap hits.
- Defense that is tedious, for example demanding four separate reactions for every enemy action.
- Scope creep that stops a playable version from ever existing.

## 3. Constraints

- **Visual style:** 16-bit pixel art.
- **Team:** the creator directs and playtests, and Claude writes most of the code and project setup.
- **Engine:** Godot 4, latest stable version, free and open source.
- **Party size:** 6 playable characters in total, 4 in battle at once.
- **Platform:** PC (Windows) first **[builder's call]**. Godot can export to other platforms later.

## 4. Approaches considered (engine)

| Option | Trade-offs | Outcome |
|---|---|---|
| **Godot 4** | Free with no royalties, strong at 2D pixel art, plain-text project files so Claude can build most of it while the creator plays and directs. Proven by Cassette Beasts (a turn-based pixel-art RPG), Brotato and Dome Keeper. | **Chosen** |
| GameMaker | Excellent for 2D pixel games, but editor-centric, so harder for Claude to build in. Exporting needs a paid license. | Rejected |
| RPG Maker | Easiest for classic RPGs, but built around standard menu battles. Live dodge and parry combat would mean fighting the tool. | Rejected |
| Unity | Capable, but heavier than a 2D game needs. | Rejected |

**Art approach (chosen):** placeholders and free 16-bit asset packs (for example from itch.io) first, to prove the combat feels good. Custom art later in Aseprite (about $20) or LibreSprite (free).

## 5. Combat design

### 5.1 Player turn: calm and strategic
- No clock runs while the player chooses an action (attack, skill, item, swap).
- **Timed attacks:** pressing a button at the right moment during an attack adds bonus damage or effect. This is optional, but rewarded.
- **[builder's call]** Missing the timing still lands a normal hit. Timing adds a bonus and failing it never cancels the action, so the player's own turn stays low-stress.

### 5.2 Enemy turn: the soulslike part
- The player must react to enemy attacks with a **dodge or parry** timed to the attack's animation.
- **[builder's call]** The targeted character is clearly highlighted before the attack lands.
- **[builder's call]** A party-wide attack needs one well-timed input that protects everyone, never four separate inputs.
- **Every character can parry, dodge and block** (changed 2026-11-26 after playtesting; replaces the earlier one-style-per-character call). The button the player presses picks the defense: parry is the hardest timing and counterattacks, dodge is wider and avoids all damage, block is the easiest and takes a quarter of the damage. Characters may later differ through stats or special reactions, not by locking defenses.
- **[builder's call]** Outcomes: a perfect parry takes no damage and may counterattack, a dodge takes no damage, a late or early press takes reduced damage, and no input takes full damage.
- Enemy attacks must have readable wind-ups (telegraphs) so the player can learn the patterns. This is a core rule for every attack.

### 5.3 Turn order
- **[builder's call]** A visible timeline shows who acts next, so the player can plan around a boss's big move.

### 5.4 Party and swapping
- 6 playable characters: 4 active and 2 on the bench.
- Characters can be swapped in and out during battle.
- **[builder's call]** One free swap per turn.
- **[builder's call]** Bench characters slowly recover HP, which makes rotation a real tactic in long boss fights.
- **[builder's call]** A knocked-out character can be revived with an item or skill, or swapped out for a fresh bench character. The battle is lost only when every character, active and bench, is down.

### 5.5 Bosses as the centerpiece
- The game is built around a sequence of bosses rather than lots of filler fights.
- Each boss has its own learnable attack patterns and wind-ups.
- **[builder's call]** Regular enemies exist but are fewer and shorter. They teach mechanics that later bosses test.

### 5.6 Battle screen sketch (placeholder names)

```
 [Boss]                         Turn: Mira > Boss > Kael > Ren
   ███
  █████        <- "Crushing Swing" targeting REN
   ███

  Kael   Mira   Ren*   Tess        Bench: Oda, Vey
  HP▮▮▮  HP▮▮   HP▮▮▮  HP▮
```

## 6. Losing: the tiered assist system

When the party loses to a boss, the loss count for that boss determines the options offered:

| Losses to this boss | Options |
|---|---|
| 1 to 3 | Respawn at the nearest save point. |
| 4 to 10 | Respawn at the save point, **or** retry the fight instantly with the boss at full HP. |
| 11 to 20 | As above, **or** retry instantly with the boss keeping the HP it had when the party lost. |
| 21+ | As above, **or** retry instantly with the boss at 1 HP. |

The assist is offered as an **option**, so the player can always choose the save point.

**[builder's calls]**
- The loss counter is **per boss** and resets when that boss is defeated.
- On an instant retry, the party returns **fully healed**. Only the boss's HP follows the table.
- "Boss keeps its HP" uses the boss's HP at the moment of the most recent loss.
- No penalty for using the assist. At most a small, optional marker on the save file. Nothing is locked out.

## 7. Outside battle
- Exploration and story are the calm part of the rhythm.
- Save points exist in the world and are where the party respawns.
- Everything else (maps, towns, dialogue, progression and leveling, items and equipment) is to be designed later.

## 8. First milestone: the combat slice

Before anything else, build **one complete boss fight** to prove the combat feels right. Story, exploration and other systems wait until this feels good.

The slice includes:
- A battle scene at a 16-bit resolution of 320x180, scaled up cleanly to the screen **[builder's call]**.
- 6 placeholder characters (4 active, 2 bench), each with a basic attack, one or two skills and a distinct defense style.
- Timed attacks on the player turn.
- Dodge and parry on the enemy turn, with clear telegraphs.
- The turn-order timeline.
- Swapping, bench recovery and knock-outs.
- One boss with at least 3 distinct, learnable attack patterns.
- The tiered loss assist working (a debug option can set the loss count for testing).
- Keyboard and gamepad controls **[builder's call]**.

**Done means:** the creator plays the fight several times, it keeps them alert, and they want to try again after losing.

## 9. Left to the builder
- Code architecture, file structure and scene layout in Godot.
- Exact timing windows, damage numbers and balance values, tuned through playtesting with the creator.
- Choice of placeholder art and sound.
- Input mapping details.

## 10. Decided later (by the creator)
- Story, setting, world and tone.
- Character identities, names and personalities.
- Progression (levels, skill trees, equipment).
- Exploration structure (open world or linear, size and number of areas).
- Final art direction and whether to draw it or commission it.
