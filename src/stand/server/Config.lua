-- All spatial/timing values below are stand calibration, not measured NES units.
return {
    Calibration = "EXPERIMENTAL_STAND_ONLY",
    WalkSpeed = 16,
    JumpPower = 42,
    MoveTimeout = 0.35,
    SpawnRetry = 0.5,
    DeathDelay = 0.8,
    FallY = -35,
    MaxIntentRate = 40,
    SnapshotInterval = 0.1,
    MaxLogEntries = 256,
    Impulses = {
        [18] = {horizontal=9, vertical=0},
        [21] = {horizontal=34, vertical=27},
        [22] = {horizontal=32, vertical=18},
    },
    Attacks = {
        Punch = {windup=0.10, window=0.12, cooldown=0.55, reaction=28/60,
            reach=6, width=3, height=4},
        Dash = {windup=0.18, window=0.14, cooldown=1.0, reaction=0.75,
            reach=8, width=3, height=4},
    },
}
