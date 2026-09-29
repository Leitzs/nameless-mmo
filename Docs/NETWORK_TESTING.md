# Network testing: scenarios, known issues, latency bugs

How to keep the multiplayer stable. The architecture is described in `godot/README.md` ("Networking").
`G` below is `Godot_v4.7.2-stable_win64_console.exe` (the console build prints logs).

## 1. Automated checks (run after every netcode change)

| # | Command | Expected | Last result |
| --- | --- | --- | --- |
| A1 | `G --headless --path godot -- --selftest` | `ALL PASSED` (offline path = offline server) | 138/138 |
| A2 | `G --headless --path godot -- --selftest-net` | `ALL PASSED`, "0 corrections" | 20/20, 0 corrections |
| A3 | `G --headless --path godot -- --selftest-net --via-proxy 80` | `ALL PASSED` | 20/20, 4 corrections, 4.4 m moved (see B1) |
| A4 | `G --headless --path godot -- --selftest-net --via-proxy 150` | `ALL PASSED` | 20/20, 6 corrections, 4.4 m moved (see B1) |

`--selftest-net` starts a headless dedicated server on port 7790 and a dummy client, optionally a
`tools/net_proxy` on 7791 (latency = the given ms one-way, jitter ms/8, 1% loss). Then it joins as a
Pyromancer and checks the following, printing PASS/FAIL per line (`godot/scripts/net/net_self_test.gd`):
- handshake and tick rate adoption;
- level and character replication;
- interpolation;
- FFA hostility;
- 1 s of predicted movement;
- that the server's state agrees with the prediction;
- soft-lock on and a Firebolt hit against the other player;
- damage events;
- a server-side cooldown rejection and cooldown replication;
- leaving the session.

It kills its child processes on exit. If a run is aborted, kill any leftover
`Godot_v4.7.2-stable_win64_console.exe` processes, or ports 7790/7791 stay busy.

Worth adding to the automated suite:
- 250 ms latency and 5% loss;
- jitter bigger than the tick (40 ms at 60 Hz, which reorders packets);
- 128 Hz and 30 Hz servers;
- 4+ dummy clients;
- a client that disconnects mid-cast;
- a late joiner while zones and projectiles are alive.

## 2. Manual scenarios

Open the F3 overlay in every window. Add `--net-log` to servers to get a line every 2 s. Use two
game windows on one PC, or two PCs on a LAN. For latency, put `tools/net_proxy.tscn` between them:

```
G --headless --path godot tools/net_proxy.tscn -- --listen 7778 --target 127.0.0.1:7777 --latency 80 --jitter 15 --loss 2
```

Then join `127.0.0.1:7778`.

| # | Scenario | Steps | Expect / watch |
| --- | --- | --- | --- |
| M1 | Host + join (LAN) | Window A: Multiplayer, Host. Window B: Multiplayer, Join 127.0.0.1 | B sees A and the bots move smoothly. Nameplates show player names. Menus don't pause the game. |
| M2 | Local feel under latency | Through the proxy at 80/150/250 ms, run, jump, sprint, strafe against pillars and the ramp | Your own movement is instant. F3 corrections stay ~0 while moving in a straight line, and last error < 0.05 m at rest. |
| M3 | Remote smoothness | B watches A running circles through the proxy with 15-40 ms jitter | No stutter or popping. F3 "buffered" stays >= 1. |
| M4 | PvP hit registration | A strafes and B hits with bolts, cones (Flame Wave), melee (Nightblade) and Chain Lightning, at 0/80/150 ms | Hits that look like hits land. Lag compensation is max 200 ms, so past ~200 ms they stop landing. |
| M5 | Telegraphs | A casts Meteor / Cataclysm near B | B sees red, A sees their own colour. Moving out of a telegraph avoids the hit at any latency. |
| M6 | Knockback / CC on a client | Bot charge, Flame Wave, Frost Nova, stun, root on the client's player | Pushes and freezes apply once, with no rubber-banding loop. With latency they show after RTT and then settle. |
| M7 | Mobility spells | Blink, Ember Dash, Shadowstep, Thunder Step as a client at 150 ms | Works, with a visible snap after the RTT (see B3). |
| M8 | Ice Wall | Cryomancer walls across a client's path | The client collides with the wall and doesn't jitter through it. Projectiles stop at it. |
| M9 | Stealth | Rogue Vanish / Nightblade Smoke Bomb near an enemy player | The enemy player loses you (you are not in their snapshots). An ally or you see a transparent character. |
| M10 | Death + respawn | Kill a client | Death animation, "Respawning in 3", respawn at the spawn point farthest from others. |
| M11 | Class change | Client: pause, Class Selection, pick another class | Respawns as that class. The HUD updates. |
| M12 | Inventory / Grimoire | Client uses a potion, drags slots, sorts, switches a spell modifier | Applied by the server. The UI updates within ~RTT and nothing is duplicated or lost. |
| M13 | Late join | Join while zones, summons and bots are active | Characters, summons and bots appear. Zones and projectiles already alive are not shown (B6). |
| M14 | Leave / rejoin | Client leaves and rejoins; host leaves | The client's character disappears for others. When the host leaves, clients get "Disconnected" and go back offline. |
| M15 | Hard disconnect | Kill a client process (Task Manager) | The server drops the peer after the ENet timeout (a few seconds). No errors spam. |
| M16 | Dedicated server | `G --headless --path godot -- --server --net-log`, then 2 clients | Same as M1. The server log shows join/leave and stats. |
| M17 | Tick rates | Host at 30 and at 128 Hz (Host panel or `--tick-rate`) | Clients adopt it (F3). At 128 Hz check server CPU and `out kB/s`. |
| M18 | Soak | 2-4 clients + bots, 30 min with `--net-log` | Input queue stays small, `rejected`/`dropped` stay 0, no growing memory or bandwidth, no desync. |
| M19 | Bandwidth | 8 dummies: `G --headless --path godot -- --connect 127.0.0.1 --name D1` (x8) | Note the server `out kB/s` per peer (1 player + 4 bots was ~6-8 kB/s at 60 Hz). |
| M20 | Internet | Host with UPnP ticked, friend joins by public IP | The UPnP result shows as a HUD message. Without UPnP, forward UDP 7777 manually. |
| M21 | High refresh | Play on a 144 Hz monitor | Camera and characters are smooth (physics interpolation is on). No jitter when turning. |

## 3. Known issues and latency bugs (open)

- **B1: server simulates slightly less movement than the client predicted under latency.**
  At 80-150 ms (A3/A4) 1 s of running ends at 4.4 m on the server vs 4.9 m locally, with 4-6
  corrections (0 on localhost). The client then snaps back ~0.5 m.
  - Suspects: the stall at the start of a run, gap-filled frames (`input_stats.filled`) using the
    wrong input, frames rejected by the token bucket (`rejected`), and the double-step catch-up
    interacting with `move_and_slide` floor state.
  - Start with `--net-log` on the server and compare `filled / rejected / repeated` against the
    client's `corrections`. Log the seq numbers the server consumed against the ones the client
    replayed.
- **B2: server-side stall hitch.** When no input arrives (jitter), the server holds the player
  still for up to 12 ticks (200 ms), then plays a neutral frame. Remote viewers can see a micro
  hitch under heavy jitter. A small server-side jitter buffer (start consuming at 2 queued frames)
  would smooth it.
- **B3: mobility abilities are not predicted.** Blink, dashes and steps run on the server only. The
  caster sees them after one RTT as a snap (> 1.5 m).
- **B4: cast slowdown and haste replay with the current state.** Movement while casting uses the
  casting slowdown, which the replay reads from the current time. Statuses (slow, root) replay
  with their current values. Expect small corrections at the start and end of casts and CC.
- **B5: events are not delayed to the interpolation time.** Effects, damage numbers and hit reacts
  play on arrival, about `interp_delay_ms` ahead of where remote bodies are drawn. Events are
  reliable on their own channel, so after a lost packet they can arrive up to one RTT after the
  health change.
- **B6: late joiners miss short-lived things.** Zones, projectiles, walls, blasts and Eclipse are
  replicated as events only.
- **B7: lag compensation rewinds positions only.** It rewinds positions, not poses, and applies
  only to instant logic (aim soft-lock, cone/line/radius queries at release, channel ticks). Hitscan
  raycasts against rewound bodies rely on the physics server seeing the moved bodies immediately,
  which is not covered by a test yet. Projectiles use catch-up (half the RTT, max 100 ms) instead.
- **B8: cooldowns, modifiers and inventory go to every peer.** They are replicated to all peers,
  not owner-only (a minor info leak plus bandwidth). The fix is a second, owner-only synchronizer.
  Its root must be a child node: an owner-only synchronizer rooted at the character would hide
  the character's spawn from everyone else.
- **B9: no interest management.** Every entity is in every snapshot at the full rate. Bandwidth
  grows with players x entities x tick rate.
- **B10: no host migration, authentication or encryption.** The host leaving ends the session.
  ENet traffic is plain; DTLS is available in Godot if needed.
- **B12: flaky offline check.** "Combustion consumes 4 Burn for a big blast" failed once in 4 runs of
  A1 (the damage was fine, 220; the Burn check failed). It is likely a leftover burning zone or
  meteor from an earlier cast re-applying Burn. It isn't network related, but it makes A1
  occasionally red.
- **B11: headless-only verification.** Everything above was verified headless. The visual scenarios
  (M3, M5, M9, M21) still need a real run in windows.

## 4. Debugging tips

- F3 on a client:
  - `corrections` and `last error`: prediction health (0 / < 0.05 m when idle is good);
  - `unacked`: roughly RTT x tick rate;
  - `buffered`: interpolation headroom (0 means extrapolating, so raise `--interp-ms`).
- F3 or `--net-log` on the server: per-peer `rtt`, `loss`, `queue` (should hover at 0-3) and
  `inputs {rejected, dropped, repeated, filled}`.
- Godot's own tools: the editor Debugger has a Network Profiler (RPC / synchronizer bandwidth per
  node) for windowed runs.
- Protocol changes: bump `Net.PROTOCOL_VERSION` so mismatched builds are refused cleanly.
