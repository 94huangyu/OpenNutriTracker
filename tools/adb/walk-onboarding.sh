#!/usr/bin/env bash
# Retired in the intake-only fork: the upstream flow clears app data and
# depends on body-profile onboarding. Original implementation remains in Git.
# Stop before sourcing drivers, selecting devices, building or touching data.
printf '%s\n' '此遗留脚本已在本Fork停用：旧流程会清空App数据并填写身体资料。请先读 docs/china-fork/CURRENT_STATE.md 和 tools/adb/README.md。' >&2
# Returning also makes an accidental source stop without exiting its caller.
return 2 2>/dev/null || exit 2
