# Studio God Mode

The requested God Mode provides infinite respawns for Studio testing. Damage, death, recovery, actor replacement, checkpoints and normal shields continue to use the existing lifecycle. Infinite respawns are represented by a boolean, never by a large fake stock value. The finite reserve is preserved while the mode is enabled and resumes when it is disabled.

The server alone authorizes the mode. Published play always denies it. Studio exposes a ServerStorage attribute, `BrickToadsGodMode`, enabled by default for future test runs and changeable through MCP. It is applied to existing active groups and read at the beginning of new groups/runs. There is no client toggle remote. Eliminated heroes and closed runs are not revived by enabling the mode.

HUD hero reserves show `∞` and a localized God Mode label. The completed native25 campaign remains a finite-lives result: all13 levels/allboss phases Won, one paid respawn, two remaining. God Mode is verified separately with more than four genuine lifecycle appearances and an isolated Studio test after exporting/cleaning native25.
