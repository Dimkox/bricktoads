-- Original playable prototype calibration. Resource limits are canonical.
-- Enemy damage and spatial/timing values still need the full source transfer.
return function(base,level)
    local config=table.clone(base)
    config.Attacks=table.clone(base.Attacks)
    config.Impulses=table.clone(base.Impulses)
    -- Internal Club is never a permitted client attack name. Distances/times are calibrated.
    config.Attacks.Club={windup=.16,window=.16,cooldown=.7,reaction=.75,reach=9,width=3.5,height=4}
    config.Impulses[2]={horizontal=26,vertical=22}
    config.Impulses[20]={horizontal=26,vertical=22}
    config.WalkerClub={pickupRange=4.5,pickupHeight=3,npcDamage=2}
    config.Calibration='PLAYABLE_PROTOTYPE'
    config.Enemy={hearts=3,punchDamage=1,dashDamage=2,speed=9,range=5,windup=.65,cooldown=1.6,reaction=.35,attack='Dash'}
    -- Source standing28/2A and running40 effects; all seconds/studs are Roblox tuning.
    config.Attacks.PigJab={windup=.30,cooldown=.8,reaction=28/60,reach=6,width=3,height=4,recoveryPose=.20}
    config.Attacks.PigHeavy={windup=.55,cooldown=1.3,reaction=.75,reach=6,width=3,height=4,recoveryPose=.30}
    config.Attacks.PigRush={windup=.22,cooldown=1.4,reaction=.75,reach=6,width=3,height=4,recoveryPose=.35}
    config.Impulses[0]=table.clone(config.Impulses[18])
    config.Impulses[4]=table.clone(config.Impulses[22])
    config.Pig={rushAfterZone=3,rushSpeed=16,alignment=2,decisionInterval=.1,
        rushRoll=32,npcDamage={PigJab=1,PigHeavy=2,PigRush=2},
        npcProfile={PigJab=0,PigHeavy=2,PigRush=4}}
    config.Attacks.WalkerLight={windup=.40,cooldown=1.0,reaction=28/60,reach=7.5,width=3.25,height=4,recoveryPose=.20}
    config.Attacks.WalkerHeavy={windup=.65,cooldown=1.6,reaction=.75,reach=7.5,width=3.25,height=4,recoveryPose=.35}
    config.Walker={range=6.5,minRange=2.5,retreatSpeed=7,
        npcDamage={WalkerLight=1,WalkerHeavy=2},npcProfile={WalkerLight=0,WalkerHeavy=2}}
    config.Boss={hits=3,interval=2.4,projectileSpeed=12,returnSpeed=26,projectileLife=12,aggroRange=45}
    config.BossQueue={inviteSeconds=10,connectSeconds=15}
    config.Groups={maxGroups=4,spacing=512}
    config.Level=level
    -- Studs, seconds and radians/second; not claimed original NES timing.
    config.HealingFlies={range=6,height=3,facingDot=.25,windup=.16,bobHeight=.25,bobSpeed=2}
    -- Original close Pig grab/throw; existing3HP damage is still prototype tuning.
    config.EnemyCarry={range=3.3,height=2.5,facingDot=.5,windup=.12,window=.2,reaction=.85,
        horizontal=26,vertical=16,throwDamage=config.Enemy.punchDamage,sourceProfile=17,sourceRawDamage=4}
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
