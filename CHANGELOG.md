# Changelog

## 1.0.59 - 2026-07-01

- Backed up the current working tree and prior Android artifacts to the AI volume before cleanup.
- Removed tracked legacy regression evidence under `测试数据统计` and retired old one-off/monolithic test runners that are no longer part of the current Neijiang release gate.
- Updated the README and current regression map so release validation points at `tests/current/*`, C# smoke, Python tooling tests, and fixed-seed AI pressure runs.
- Preserved the 1.0.58 realtime AI rule set and keep-ready defense behavior; this release is focused on cleanup, verification, and packaging hygiene.

## 1.0.58 - 2026-07-01

- Changed the formal AI turn/reaction path to compute against the current realtime table state by default, while preserving explicit native-async test coverage for the async backend.
- Defined Neijiang AI stage evaluation by wall count, discard progress, exposed meld pressure, and likely-ready pressure so early/middle/late strategy is no longer ambiguous.
- Tuned opening route judgment for pinghu, qidui, qingyise, and five-pair concealed hands, including pass protection for qidui/long-qidui potential before committing to calls.
- Added a late-wall keep-ready guard after hard-defense overrides so the final discarded tile does not break a ready hand when a higher-score ready candidate has acceptable danger.
- Verified the selected release rule set with 30 fixed-seed realtime bone-ash AI rounds: `forced_stop_rounds=0`, average discard quality `95.15`, A/B acceptable rate `93.71%`, D/E error rate `4.64%`, and E-level blunders `24/668`.

## 1.0.57 - 2026-06-28

- Added automated long-term AI pressure-evaluation output for score delta, deal-in rate, deal-in loss, draw/battle-end distribution, phase counts, and final debug snapshots across all-AI benchmark runs.
- Added turn-quality diagnostics and training-index fields for selected danger, mode consistency, expected-net gaps, route alternatives, opportunity-loss flags, and candidate quality scores.
- Fixed C# discard selection so strategy-aware sorted candidates update the actual chosen tile, score, shanten, live-ukeire, and explain reasons instead of only reordering diagnostics.
- Tuned long-term EV policy so medium trailing positions stay balanced unless the score gap or final stretch justifies chase mode.
- Verified 300 fixed-seed automated pressure rounds with `forced_stop_rounds=0`; the final fixed-seed score path stayed unchanged, while the selection path and diagnostics are now internally aligned for further batch tuning.

## 1.0.56 - 2026-06-28

- Added `AIContextCache` for C# discard decisions, covering stage, round goal, strategy mode, hand analysis, attack eligibility, opponent danger, tile danger, score situation, risk tolerance, dirty flags, explain reason codes, and module timing.
- Added old-hand strategy evaluators for `attack`, `balanced`, `defense`, `fold`, and `chase`, plus strategic deal-in risk adjustment without hardcoding a fixed discard.
- Passed score, round, hand-version, and visible-version context through the Godot C# bridge, native runtime, CLI fallback, and decision cache fingerprint so score-aware strategy cannot reuse stale cached decisions.
- Added smoke coverage for AI context stage/explain/performance output and score-driven strategy mode switching.
- Re-ran the opening bao-jiao/bao-gang stall regressions covering AI-only bao-jiao, AI bao-gang, human bao-jiao/bao-gang, stale AI turn rejection, native C# contract mapping, and UI turn-resume paths.

## 1.0.55 - 2026-06-26

- Fixed a reported bao-jiao/bao-gang stall where an AI turn could reuse a stale cached discard `tile_id` after the hand changed, causing the table to stop when the opposite AI should discard.
- AI turn execution now rejects cached decisions that are no longer executable and refreshes the decision once against the current hand before giving up.
- Added a regression case for the reported shape: human dealer already declared bao-jiao/bao-gang, opposite AI already declared bao-jiao, and the AI turn recovers from a stale discard cache by discarding the legal drawn tile.

## 1.0.54 - 2026-06-25

- Fixed a real opening bao-jiao UI stall where stale draw-transition state could hide the human `报叫` and `过` controls after an AI player declared bao-jiao.
- Added a live MainScene replay that uses the real AI manager and Godot timers to reproduce AI bao-jiao before the human opening prompt, then verifies the buttons are visible.
- Added UI regression coverage for a reported AI discard-reaction path so AI bao-jiao followed by AI reaction does not leave the table stuck.

## 1.0.53 - 2026-06-25

- Fixed the opening AI bao-jiao/bao-gang completion path so the state broadcast happens after advancing to dealer first discard, preventing the UI from holding a stale no-action snapshot.
- Added UI regression coverage for AI opening bao-jiao with bao-gang where the human player is not also declaring, then continued the round until the human draws and discards.
- Added matching UI regression coverage for the AI opening bao-jiao-only path, including intermediate AI turns before control returns to the human player.

## 1.0.52 - 2026-06-24

- Fixed the opening bao-jiao/bao-gang dialog flow so the top-right close button cancels instead of silently submitting, and an explicit `确认报叫` button submits the selected bao-gang choices.
- Added current smoke coverage for a real opening deal where the human declares opening bao-jiao with selected bao-gang keys and the AI dealer proceeds to first discard.
- Added UI regression coverage for the bao-gang dialog cancel/confirm path and refreshed helper-text assertions to match the current in-game wording.

## 1.0.51 - 2026-06-23

- Preserved the AI-mode contract by mapping legacy cheating-level entrypoints to the `hell` preset and legacy advanced entrypoints back to `bone_ash`.
- Recognized `hell_challenge_direct_sync_delivery` as a direct hell challenge backend so synchronous hell decisions keep the same oracle execution/diagnostic path as direct and async hell decisions.
- Added current smoke coverage for legacy AI-level preset mapping and direct hell challenge sync-delivery recognition.

## 1.0.50 - 2026-06-18

- Fixed an opening bao-jiao/bao-gang stall where AI declarations could recursively advance the opening review queue and leave the round stuck before dealer first discard.
- Kept bao-jiao/bao-gang judgment backend-owned: C# still decides AI declarations, while Godot only advances the reviewed queue and executes the returned action.
- Added current smoke coverage for AI opening declaration stopping at the human prompt, and for human pass resuming queued AI review before dealer first discard.

## 1.0.49 - 2026-05-21

- Fixed reported bao-gang stalls by sending the declared `bao_gang_tiles` whitelist to C# as `baoGangTileTypes`.
- C# now independently forces reported bao-gang for both self-draw gang and discard-reaction gang, even if the frontend mandatory marker is missing.
- Added regression evidence for the two suspected stuck cases: reported self-draw an-gang and reported reaction melded gang.

## 1.0.42 - 2026-05-20

- Reworked the bao-jiao AI stall fix so the frontend no longer substitutes a discard decision; it remains a legality guard and rejects illegal original-hand discards.
- Fixed the C#/Godot discard contract for bao-jiao turns by mapping backend tile-type decisions to the actual just-drawn tile id when the hand contains duplicate same-type tiles.
- Added native hell-challenge coverage proving the backend returns `bao_jiao_route` for bao-jiao turns and the mapped Godot discard id is the last-draw tile.

## 1.0.41 - 2026-05-20

- Fixed a bao-jiao AI stall where the backend could recommend discarding an original locked hand tile and the frontend rejected it without progressing the turn.
- Bao-jiao AI now falls back to discarding the just-drawn tile when a discard recommendation would violate the bao-jiao lock, while still blocking discard if that draw is a mandatory bao-gang tile.
- Added regression coverage using the same locked-tile plus just-drawn-tile shape from the stalled AI turn.

## 1.0.40 - 2026-05-20

- Disabled runtime diagnostic export, AI analysis/training logs, and auto-learning file persistence for the practical-use Android package.
- Hid diagnostic export, hell-marking, tuning, and opponent-hand developer buttons from the in-game floating tools.
- Kept the 0.5-3.0 second randomized AI table pacing from 1.0.39.

## 1.0.39 - 2026-05-20

- Slowed visible AI table actions with a randomized 0.5-3.0 second thinking delay for turns and reactions.
- Kept C# AI decision quality unchanged; this release only adjusts table pacing and Android package metadata.

## 1.0.38 - 2026-05-19

- Fixed hell-challenge async discard decisions so C# callback results are checked by the same oracle path as synchronous discards before the tile is played.
- Enlarged the bao-gang selection dialog with bigger title text, option rows, and option fonts for phone readability.
- Strengthened bao-jiao lock, mid-hand risk, and hell-challenge regression coverage for discard and oracle behavior.

## 1.0.30 - 2026-05-15

- Improved discard/action responsiveness by separating stale AI calculations from current human input and adding safer async decision signatures.
- Added belief-cache diagnostics and performance-oriented posterior reuse without changing the core AI scoring contracts.
- Tuned early offensive hand-shape evaluation so strong pair-heavy starts keep higher-value routes instead of over-breaking useful groups.
- Added player-selected bao-gang declarations during bao-jiao, with backend validation and mandatory future gang enforcement.

## 1.0.26 - 2026-05-13

- Restyled the main action buttons into large circular mahjong controls with primary yellow-orange and secondary green variants.
- Restored selected-hand AI explanation details so the discard helper shows C# candidate comparisons, posterior reasons, risk reasons, and expected-score deltas.
- Enlarged the AI discard helper into a wider phone-readable prompt with larger outlined text.
- Added UI regression coverage for circular action buttons and C# candidate detail display in the helper panel.

## 1.0.25 - 2026-05-13

- Set this snapshot as the new stable development base after the `1.0.24` baseline.
- Refined the main table presentation, including a larger center wall-count disc, no desktop frame line, and a simplified right-side control stack with a top-right exit button.
- Fixed Neijiang Mahjong flow priorities so opening bao-jiao decisions block automatic dealer discard until resolved.
- Fixed self-hu and settlement UI details so self-hu no longer shows discard guidance and Neijiang settlement no longer displays stale missing-suit text.
- Updated Android package metadata and export scripts so generated APK filenames include the version number.

## 1.0.4 - 2026-05-10

- Replaced the self-hu source text label with the same arrow-style claim marker used elsewhere.
- Reduced the left and right opponent meld tiles a little more so the side meld areas feel less oversized.
- Updated the contract and preview capture to lock the new claim badge and smaller side meld size.

## 1.0.3 - 2026-05-10

- Centered the AI discard helper on the main board and made the prompt reason line readable on mobile.
- Updated the discard hint preview to show a short reason directly under the recommended tile text.
- Bumped the tracked source and Android package versions to keep the release metadata in sync.

## 1.0.2 - 2026-05-10

- Enlarged the floating AI discard helper and reduced it to centered direct content so the hint stays readable on mobile.
- Replaced the recommended-tile outline marker with a continuously rotating cone centered on the suggested tile.
- Updated the V17 layout contract to lock the helper panel readability rules and cone marker behavior.

## 1.0.1 - 2026-05-10

- Tuned the opposite player's hand, meld, and winning-tile lane to sit closer to the player info area without overlapping it.
- Reduced left/right opponent meld tile scale and recalculated side winning-tile slots so the tile stays inside the frame.
- Updated the V17 layout contract to lock the new opponent lane spacing and side winning-tile behavior.

## 1.0.0 - 2026-05-10

- Created the first GitHub-ready source snapshot for the Neijiang Mahjong Godot project.
- Added repository hygiene for Godot, .NET, Android build outputs, export artifacts, and signing files.
- Recorded the baseline app version and version-management workflow.
