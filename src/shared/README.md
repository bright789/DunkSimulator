# Shared Source

Place modules that are safe for both server and client use here, such as immutable configuration, types, constants, and identifiers. Do not place server secrets or authoritative mutable player state in shared modules.

`Config/ProgressionConfig.luau` defines starting stats, base training progress, tick interval, interaction range, cap-feedback cooldown, and the jump-height curve. `Config/UpgradeConfig.luau` defines training efficiency/prices; `Config/CourtConfig.luau` defines validated court bonuses and training limits. Only server services apply progression changes; shared configuration contains no player state.

`Config/DunkConfig.luau` defines pickup range/cooldown, ball appearance, and dunk tolerances. `Config/DunkStyles.luau` defines style thresholds/base rewards, `Config/DunkRewards.luau` defines the Vertical Cash bonus and paid air-trick combos (`docs/DUNK_REWARDS.md`), `Config/DunkAnimations.luau` contains empty slots for legitimately published R15 IDs, and `Config/DribbleConfig.luau` tunes automatic bounce and temporary IK. The server uses private player state and these definitions for validation and awards.
