-- Original playable prototype calibration. Resource limits are canonical.
-- Enemy damage and spatial/timing values still need the full source transfer.
return function(base,level)
    local config=table.clone(base)
    config.Calibration='PLAYABLE_PROTOTYPE'
    config.Enemy={hearts=3,punchDamage=1,dashDamage=2,speed=9,range=5,windup=.65,cooldown=1.6,reaction=.35,attack='Dash'}
    config.Boss={hits=3,interval=2.4,projectileSpeed=12,returnSpeed=26,projectileLife=12,aggroRange=45}
    config.BossQueue={inviteSeconds=10,connectSeconds=15}
    config.Groups={maxGroups=4,spacing=512}
    config.Level=level
    if level then
        config.Calibration='ORIGINAL_3D_ROUTE_STATIC_ROSTER'
        config.Boss.interval=1.6
        config.Boss.ballInterval=8
        config.Boss.ballLife=20
        config.Boss.pickupRange=5.5
        config.Boss.rawLife=47
        config.Boss.throwDamage=16
    end
    return config
end
