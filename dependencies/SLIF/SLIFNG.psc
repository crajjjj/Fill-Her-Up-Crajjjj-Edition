Scriptname SLIFNG Hidden
{SLIF NG native engine surface (SLIFNG.dll). The pinned SLIF_* shims route
here; the whole pipeline (legacy-key cleanup, vocabulary incl. dead-key
no-ops, clamp, keyed per-mod ledger, configurable fold, ONE coalesced skee
apply) runs natively. Values: node targets 1.0 = neutral, morphs 0.0 = neutral.
min/max/mult accept -1.0 = "keep defaults" (0 / 100 / 1.0).}

; API version of the native surface.
; 2: increment parameter on Inflate/Morph, incremental inflation, and the
;    enumeration surface for mod authors (IsTracked/GetTrackedActors/...).
; 3: HasTarget - ask whether a target would do anything BEFORE writing to it,
;    and region overlay files (Bodies/Regions/*.ini) so a consumer mod can
;    contribute a custom region without owning the user's body profile.
; 4: SetRampSpeed/GetRampSpeed - the user's speed preference for incremental
;    inflation. A multiplier on YOUR increment, so it retimes your ramp
;    without overriding the step size you asked for.
; 5: DrivenBy, and the SLIFNG_Settled mod event (see below).
Int Function GetVersion() Global Native

; Returns true when the value changed and was applied (false = early-out,
; dead key, unknown key, or missing engine).
; slifKey accepts EITHER a slif_* key OR a raw skeleton node name ("NPC Belly"
; - what FHU sends); both resolve to the same canonical target.
; increment: the per-row step for incremental inflation (SLIF's own knob;
; -1.0 = keep the default 0.1). Only consumed while incremental mode is on.
; slifKey also accepts a SLIF NG "region:<name>" semantic key: the actor's
; body profile maps it to sliders via its [<name>] section ("region:weight" ->
; [Weight]). Node-scale semantics (1.0 = neutral), profile sliders only - no
; skeleton bone behind it; a profile without the section is a logged no-op.
Bool Function Inflate(Actor kActor, String modName, String slifKey, Float value, Float minimum, Float maximum, Float multiplier, Float increment, String oldModName) Global Native
Bool Function Morph(Actor kActor, String modName, String morphName, Float value, Float minimum, Float maximum, Float multiplier, Float increment, String oldModName) Global Native

Function UnregisterNode(Actor kActor, String slifKey, String modName) Global Native
Function UnregisterMorph(Actor kActor, String morphName, String modName) Global Native
Function UnregisterMod(Actor kActor, String modName) Global Native

; Calculation type - SLIF's own six, SLIF's own Config.json numbering, SLIF's
; own default (CONTRACT sec.4.3):
;   0 = Top X (DEFAULT: largest + second/3 + third/6)   1 = Highest wins
;   2 = Subtract and add one (1 + sum of deviations)    3 = Square root
;   4 = Average                                         5 = Additive (plain sum)
; Folds ACROSS MODS on one target - node scales and sliders alike (a mod's
; own node+morph layers still add; see CONTRACT sec.4.3). Switching
; recomputes and re-applies every tracked actor in one pass - with no stale
; leftovers, unlike the reference.
Function SetAggregationMode(Int mode) Global Native
Int Function GetAggregationMode() Global Native

; ---- the reference's READ surface (SLIF_Main/SLIF_Morph.Get*Value) ----
; target: a slif_* key, a raw skeleton node, or "morph:<slider>".
; modName "All Mods" reads the fold; any other name reads that mod's own row.
; An ABSENT key returns `default` - the reference reads StorageUtil with the
; caller's default, so "nothing registered" must not read as a neutral value.
Float Function GetValue(Actor kActor, String modName, String target, Float default) Global Native
Float Function GetMinValue(Actor kActor, String modName, String target, Float default) Global Native
Float Function GetMaxValue(Actor kActor, String modName, String target, Float default) Global Native

; ---- hidden nodes (Devious Devices pins the belly under a chastity belt) ----
; A hide OVERRIDES the fold instead of competing with it, and is keyed by
; actor+target rather than by mod, matching the reference's per-actor
; `<node>_hidden` flag. See Ledger.h for what "hidden" means on a morph body.
Function HideNode(Actor kActor, String modName, String slifKey, Float value, String oldModName) Global Native
Function ShowNode(Actor kActor, String modName, String slifKey) Global Native

; Diagnostics: a mod's stored raw value / the folded applied value for a
; target ("slif_belly" or "morph:<slider>").
Float Function GetContribution(Actor kActor, String modName, String target) Global Native
Float Function GetApplied(Actor kActor, String target) Global Native

; The reference's "slif_<morphName>": the cross-mod sum of direct morph
; contributions for one slider. SLIF_Morph mirrors it into StorageUtil under
; that exact name - Sexlab Survival reads it from StorageUtil directly.
Float Function GetCombinedMorph(Actor kActor, String morphName) Global Native

; ---- batch writes (SLIF NG extension, one coalesced apply) -------------------
; Arrays pair by index (keys[i] with values[i]); bounds arrays may be shorter -
; missing entries mean "keep defaults". Returns how many entries changed.
; Ramping entries ramp individually; the rest land in ONE apply per actor.
Int Function InflateMany(Actor kActor, String modName, String[] slifKeys, Float[] values, Float[] minimums, Float[] maximums, Float[] multipliers, Float[] increments, String oldModName) Global Native
Int Function MorphMany(Actor kActor, String modName, String[] morphNames, Float[] values, Float[] minimums, Float[] maximums, Float[] multipliers, Float[] increments, String oldModName) Global Native

; ---- incremental inflation (the reference's "Inflation Type") ---------------
; ON by default (a deliberate SLIF NG choice; the reference shipped instant).
; When on, node-value CHANGES step toward their new fold by each row's
; increment every quarter second, entirely off the Papyrus VM;
; hide/unregister stay instant. Turning it off snaps every in-flight ramp to
; its final value.
Function SetIncrementalInflation(Bool enabled) Global Native
Bool Function IsIncrementalInflation() Global Native

; How fast incremental inflation travels: a multiplier on the increment YOUR
; call supplied, so the user can pace ramps without overriding a mod's step.
; Clamped to 0.1 - 5.0; read every step, so it retimes ramps already moving.
; Consumers rarely need these - the MCM owns this setting. Requires GetVersion() >= 4.
Function SetRampSpeed(Float speed) Global Native
Float Function GetRampSpeed() Global Native

; ---- query surface for mod authors ------------------------------------------
; The values come through GetValue / GetApplied / GetContribution /
; GetCombinedMorph above; these answer "what is there to ask about".
; C++ plugins get the same surface via messaging - see src/API/SLIFNG_API.h.
; Would a write to this target actually do anything on this actor?
; A canonical key ("slif_belly") or a morph ("morph:X") is always true - worst
; case the skeleton node drives it. A "region:<name>" key is true only when the
; actor's body profile defines that section, because a region is sliders or
; nothing; that is the branch to take before sending one:
;
;   if SLIFNG.HasTarget(kActor, "region:weight")
;       SLIF_Main.inflate(kActor, "My Mod", "region:weight", 1.4)
;   else
;       SLIF_Main.inflate(kActor, "My Mod", "slif_belly", 1.15)
;   endif
;
; Dead keys and unknown spellings are false. Requires GetVersion() >= 3.
Bool Function HasTarget(Actor kActor, String target) Global Native

; HOW this actor's body realises a target - what HasTarget deliberately will
; not tell you, since a canonical key is always "yes, something happens".
;   "sliders" - BodySlide morphs move vertices and NO bone moves. Anything
;               rigged to that bone (a particle emitter, an attached object)
;               does NOT follow, and needs its own offset compensation.
;   "node"    - the skeleton bone is scaled, so its children come along.
;   "none"    - a region this profile does not define, or an unknown/dead key.
; Requires GetVersion() >= 5.
String Function DrivenBy(Actor kActor, String target) Global Native

; ---- SLIFNG_Settled (mod event) ---------------------------------------------
; Sent when a target STOPS CHANGING on an actor - a plain write, the last step
; of a ramp, an unregister, or a magnitude change. NOT once per ramp step: at
; ten steps a second that would be a flood, and this is the moment consumers
; actually want ("she has finished growing, reposition and fire").
;
;   RegisterForModEvent("SLIFNG_Settled", "OnSlifSettled")
;
;   Event OnSlifSettled(String eventName, String target, Float value, Form sender)
;       ; target = "slif_breast" / "morph:PregnancyBelly" / "region:weight"
;       ; value  = the settled value, same as GetApplied(sender, target)
;       ; sender = the Actor
;   EndEvent
;
; Re-register in OnPlayerLoadGame like any mod event. Requires GetVersion() >= 5.

Bool Function IsTracked(Actor kActor) Global Native
Actor[] Function GetTrackedActors() Global Native
; Canonical node keys with a stored contribution ("slif_belly", ...).
String[] Function GetNodeTargets(Actor kActor) Global Native
; BodySlide sliders with a stored direct contribution, original case.
String[] Function GetMorphTargets(Actor kActor) Global Native
; Which mods hold a contribution to one target (key, raw node, or
; "morph:<slider>").
String[] Function GetModsDriving(Actor kActor, String target) Global Native

; Push new bounds onto one mod's existing rows for a node target, across every
; tracked actor, re-applying whoever changed (SLIF_Main.updateActorList -
; Estrus Chaurus pushes its MCM max scales this way). -1.0 = keep as stored;
; values never move.
Function UpdateModBounds(String modName, String slifKey, Float minimum, Float maximum, Float multiplier, Float increment) Global Native

; Per-ACTOR bounds, for the reference's per-actor bounds events (SLIF_setMinimum
; and friends carry a Sender). NOT the same as UpdateModBounds above, which is
; load-order-wide: using that for a per-actor event would move everyone's bounds.
Function UpdateActorBounds(Actor kActor, String modName, String slifKey, Float minimum, Float maximum, Float multiplier, Float increment) Global Native

; Diagnostics: write the full ledger (or one actor's entries) to SLIFNG.log -
; contributions, fold results, active mode. See SLIFNG_Debug.psc for
; console-callable wrappers (ConsoleUtil Extended: `slifng dump`).
; Per-call diagnostics (every API entry + apply + a skee readback per slider).
; Dev builds default ON; turn it off for normal play.
Function SetVerboseLogging(Bool enabled) Global Native

; ---- user magnitude scaling ----
; Rides on top of the fold at apply time; never changes what consumers stored,
; so it is safe to move at any point and applies retroactively to everyone.
; A scaleId is the lowercase SLIDER name for a morph target, or the canonical
; key for a node target: "pregnancybelly", "breasts", "slif_butt".
; 1.0 = unchanged, 0.0 = that output suppressed entirely.
Function SetMasterScale(Float scale) Global Native
Float Function GetMasterScale() Global Native
Function SetTargetScale(String scaleId, Float scale) Global Native
; Per-ACTOR magnitude on top of the master and per-target pair (what apply
; multiplies by is master * target * actor). Persisted with the save.
Function SetActorTargetScale(Actor kActor, String scaleId, Float scale) Global Native
Float Function GetActorTargetScale(Actor kActor, String scaleId) Global Native
Float Function GetTargetScale(String scaleId) Global Native

; One-shot legacy-import marker, persisted with the save (cosave v4). The
; import walk itself lives in SLIFNG_Migrate.psc - StorageUtil is a Papyrus API
; with no C++ interface, so the DLL cannot read the legacy keys.
Bool Function HasMigrated() Global Native
Function SetMigrated(Bool done) Global Native

; Engine availability + a count, for the MCM status lines.
Bool Function IsMorphEngineReady() Global Native
Bool Function IsNodeEngineReady() Global Native
Int Function TrackedActorCount() Global Native

; Actor diagnostics, formatted by the engine: interleaved {label, value, ...}
; where an empty value marks a section header. Same text either way.
String[] Function GetActorReport(Actor kActor) Global Native
; The same report split in two, so the MCM can pair the halves into real
; columns instead of leaving the right half blank.
String[] Function GetActorReportLeft(Actor kActor) Global Native
String[] Function GetActorReportRight(Actor kActor) Global Native
Function LogActorReport(Actor kActor) Global Native

; Probe: dump skee's known morph-name table (and one actor's morphs) to the
; log. Decides whether body detection is possible - see PLAN P2.
Function LogKnownMorphs(Actor kActor) Global Native

Function DumpLedger() Global Native
Function DumpActor(Actor kActor) Global Native
