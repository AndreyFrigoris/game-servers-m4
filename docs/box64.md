# Box64 on Apple Silicon

Box64 translates x86_64 code to ARM at run time. For Unity / Unreal dedicated servers this is the difference between “playable” and “illegal instruction crash loop”.

## Conservative profile

Stability over peak FPS. Drop this in the image’s `emulators.rc` (V Rising: `persistentdata/Settings/emulators.rc`; ARK / Conan: `persistentdata/emulators.rc`):

```
BOX64_DYNAREC_STRONGMEM=1
BOX64_DYNAREC_BIGBLOCK=0
BOX64_DYNAREC_SAFEFLAGS=1
BOX64_DYNAREC_FASTNAN=0
BOX64_DYNAREC_FASTROUND=0
BOX64_DYNAREC_X87DOUBLE=1
BOX64_DYNAREC_BLEEDING_EDGE=0
```

`BLEEDING_EDGE=1` and big dynarec blocks are faster and crash more. Do not enable them on a world you care about.

## Hosting load is a tick budget

In Enshrouded the hosting-load bar is **CPU time per tick**, not RAM. Under Box64 a single player can already sit around ~35 ms/tick (`Brand: 'Box64 on'` in the log). Two players may print `SERVER OVERLOADED`.

What actually helps:

- fewer slots;
- fewer spawners / aggro / weather;
- disable extra simulation (durability, glider turbulence, …);
- **not** adding RAM.

## Illegal instruction crash loops

Typical stack: `lib_burst_generated` / `GameAssembly` / `UnityPlayer` → Wine `Unhandled illegal instruction`.

What to try, in order:

1. **V Rising on Apple Silicon:** hide `VRisingServer_Data/Plugins/x86_64/lib_burst_generated.dll` after SteamCMD (this repo’s `start-wrapper.sh` does that). Burst SIMD is what Box64 chokes on; the crash happens at Unity init, not while loading the save.
2. Confirm the conservative Box64 profile is actually loaded (it should print at container start).
3. Cap server FPS (V Rising: `ServerFps: 20`).
4. Delete `.TEMP` under the save folder, then start once.
5. Do **not** chase it by setting `platform: linux/amd64`.

If it still loops, stop the container (`restart: unless-stopped` will otherwise spin) and look at the last log before the Wine debugger. Game updates via SteamCMD can resurrect a crash that was already “fixed”.
