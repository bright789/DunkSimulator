# Shared Source

Place modules that are safe for both server and client use here, such as immutable configuration, types, constants, and identifiers. Do not place server secrets or authoritative mutable player state in shared modules.

`Config/ProgressionConfig.luau` defines starting stats, fixed training rewards, tick interval, interaction range, and the jump-height curve. Only server services apply progression changes; shared configuration contains no player state.

`Config/DunkConfig.luau` defines pickup range/cooldown, ball appearance, dunk tolerances/cooldown/reward, and prototype feedback duration. Server services use their own copy of this configuration for validation and rewards.
