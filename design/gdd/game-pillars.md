# Game Pillars — Sight Lines

> Source: KAMA-7 (done). Committed to repo by KAMA-44.
> Canonical copy lives in the KAMA-7 issue document. This file is the
> versioned, repo-resident reference for downstream tools and agents.

---

## Core Fantasy

**"I see what others miss."**

The player is a keen observer who untangles hidden logic through patience and
insight. Every solved puzzle confirms: *I am clever enough to figure this out.*
The fantasy is not about power or speed — it is about the quiet thrill of
understanding.

## Unique Hook

A small, handcrafted puzzle game where a single core mechanic is explored with
surprising depth. The game teaches entirely through play — no text tutorials, no
hand-holding — and respects the player's intelligence from the first screen to
the last.

---

## Design Pillars

### Pillar 1: Elegant Simplicity

**Statement:** Every mechanic earns its place through depth, not breadth. We use
few mechanics but explore them thoroughly.

**Tension with:** Feature-rich / kitchen-sink design that adds mechanics for
variety's sake.

**Design Test:** *"Should we add a new mechanic type?"*
→ Only if we have exhausted interesting combinations and escalations of existing
mechanics. If the new mechanic doesn't open at least three new puzzle
configurations the current set cannot produce, it does not earn its place.

---

### Pillar 2: Aha Over Eureka

**Statement:** Puzzles produce gradual insight — "aha, I see the pattern" —
rather than sudden lucky discoveries. The player should feel clever, not lucky.

**Tension with:** Trial-and-error puzzle design where solutions are found through
exhaustive guessing or random interaction.

**Design Test:** *"Can a player solve this puzzle through understanding rather
than brute force?"*
→ If an observant player cannot reason toward the solution after studying the
puzzle state, the puzzle must be redesigned. Every puzzle should have a
*readable* logic path from problem to solution.

---

### Pillar 3: Finish What We Ship

**Statement:** Scope is sacred. A complete, polished 20-minute experience beats
an unfinished 2-hour one. Every feature that enters the build must ship at full
quality.

**Tension with:** Ambitious scope expansion, "one more level," and feature creep.

**Design Test:** *"Does adding this extend our timeline beyond what we can polish?"*
→ If a proposed addition cannot be fully implemented, tested, and polished within
current capacity, it is cut — regardless of how good the idea is. We can always
save it for the next game.

---

### Pillar 4: Show, Don't Tell

**Statement:** The game teaches through play, not through text. The environment,
level design, and audiovisual feedback communicate rules and constraints.

**Tension with:** Text-heavy tutorials, tooltip overlays, explicit instructions,
and hand-holding.

**Design Test:** *"Can a player learn this mechanic by interacting with a
well-designed introductory level?"*
→ If the answer is no, redesign the level — do not add a tutorial popup. The
first encounter with any mechanic must be a safe space where failure is cheap and
the correct interaction is visually suggested.

---

## MDA Aesthetic Priority Ranking

Ranked by importance to the target player experience:

| Rank | Aesthetic     | Role in Our Game                                                   |
|------|---------------|--------------------------------------------------------------------|
| 1    | **Challenge** | The core loop. Puzzles demand thought and reward mastery.          |
| 2    | **Discovery** | Finding new interactions, patterns, and emergent combinations.     |
| 3    | **Sensation** | Satisfying visual and audio feedback on actions and solutions.     |
| 4    | **Submission**| A meditative flow state — puzzling as a calming, focused activity. |

Aesthetics we intentionally deprioritize: *Narrative, Fellowship, Expression, Fantasy.*
These may appear incidentally but must never drive design decisions or consume
development resources.

---

## Anti-Pillars

| Anti-Pillar                          | Why We Reject It                                                                         |
|--------------------------------------|------------------------------------------------------------------------------------------|
| **"More is better"**                 | We do not add mechanics, levels, or systems for variety's sake. Depth over breadth.      |
| **"Hardcore gatekeeping"**           | Difficulty comes from genuine depth, never from obscurity or unfair information hiding.  |
| **"Story-driven design"**            | Narrative may set mood and context, but it never drives level design or mechanic choices.|
| **"Replayability through randomization"** | Handcrafted, authored levels only. No procedural generation.                        |
| **"Platform showcase"**              | We do not add features to demonstrate Godot's capabilities. Tech serves design.          |

---

## How to Use This Document

Every creative and technical decision should be traceable to at least one pillar.
When departments disagree on direction, return to these pillars:

1. **Does the proposal serve a pillar?** If not, it is out of scope.
2. **Does it conflict with an anti-pillar?** If yes, reject it.
3. **Does it pass the pillar's design test?** If not, rework or cut.
4. **Does it respect the MDA priority ranking?** Challenge and Discovery trump
   Sensation; Sensation trumps Submission.

This is a living document. Pillar amendments require Creative Director sign-off
and must be documented with rationale.
