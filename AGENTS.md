# AGENTS

## Project Snapshot
- Project: `SAMD21E` firmware/application workspace.
- Primary source tree: `Sources/`.
- Build/config surfaces: `Makefile`, `SAMD21E.xcodeproj`.
- Utility scripts/tools: `tools/`.

## Module Map
- All project code belongs under `Sources/`.
- `tools/` is reserved for non-application-code build/programming infrastructure (toolchains, upload/flashing helpers, debug/openocd scripts, and linker scripts).
- `Sources/Application/` is the default home for most app-specific logic.
- `Sources/Application/USB/` holds USB CDC application behavior and local USB glue/config files used by the app.
- `Sources/SAMD21/` is the HAL layer for basic SAMD21 MMIO/register access abstractions.
- `Sources/SAMD21/module/` contains low-level SAMD21 module/register definitions that back the HAL.
- `Sources/Support/` is the thin C support layer required to bootstrap and support the Swift HAL/runtime integration.
- `Sources/tinyusb/` is third-party library code; avoid edits unless intentionally updating vendor code.
- `tools/linker_scripts/` is specifically for linker scripts and memory layout artifacts.

## Expected Working Style
- Keep changes focused and minimal.
- Small incremental changes that can be tested and built upon with future iterations. 
- Prefer readable code over clever code.
- Do not introduce broad refactors unless requested.

## Verification Expectations
- For substantive code changes, prefer full verification when feasible:
  - full build
  - project lint/static checks (if configured)
  - tests (if available)
- If any step is skipped, document why and provide exact follow-up commands.

## Git Expectations
- Never commit unless explicitly requested.
- Avoid including unrelated files in staged changes.
- Don't use worktrees, make changes in the current branch. 
- Don't stage any changes.

## Notes for Future Updates
- If the project layout changes, update this file and corresponding rules in `.cursor/rules/`.
