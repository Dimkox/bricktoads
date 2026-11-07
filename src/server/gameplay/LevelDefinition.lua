-- Original Brick Toads geography; static actor order is derived from upstream level1_cfg.
-- Primary: feos-tas/DisAssemble, Battletoads/data/levels_cfgs1.asm.
-- Thirteen ordinary actor records: nine pigs, two walkers, two dragons.
-- This does not assert a verified natural-play total or completed NES AI/animation parity.
local function floor(x,y,z,w,d) return {x=x,y=y,z=z,w=w,h=2,d=d} end
local function enemy(id,kind,x,y,z) return {id=id,kind=kind,x=x,y=y,z=z} end
local function exit(x,z,y) return {minX=x-6,maxX=x+2,minY=(y or 3)-2,maxY=(y or 3)+6,minZ=z-13,maxZ=z+13} end
return {
    id='causeway-1',name='Затопленный тракт',
    source='https://github.com/feos-tas/DisAssemble/blob/master/Battletoads/data/levels_cfgs1.asm',
    calibration='ORIGINAL_3D_ROUTE_STATIC_ROSTER',
    zones={
        {id='Floodgate',name='Затопленные ворота',gateX=4,exit=exit(2,0),
            objective='Расчистите ворота и доберитесь до акведука',
            platforms={floor(-39,-1,0,86,52)},
            enemies={enemy(-1,'Pig',-35,3,-8),enemy(-2,'Pig',-25,3,8),enemy(-3,'Walker',-8,3,0)}},
        {id='Aqueduct',name='Разбитый акведук',gateX=124,exit=exit(122,0),
            objective='Перепрыгните разрыв и разбейте дальний дозор',
            platforms={floor(26,-1,0,44,38),floor(88.5,-1,0,71,38)},
            gaps={{minX=48,maxX=53,minZ=-19,maxZ=19}},
            enemies={enemy(-4,'Pig',20,3,-7),enemy(-5,'Pig',38,3,7),enemy(-6,'Walker',94,3,0)}},
        {id='Courtyard',name='Каменный двор',gateX=236,exit=exit(234,0),
            objective='Освободите двор перед обрывом',
            flies={{id='courtyard-fly-1',x=178,y=4.5,z=-5},{id='courtyard-fly-2',x=184,y=4.5,z=5}},
            platforms={floor(180,-1,0,112,56)},
            enemies={enemy(-7,'Pig',155,3,-10),enemy(-8,'Pig',201,3,11)}},
        {id='Cliffs',name='Обрыв и уступы',gateX=360,exit=exit(358,-6,5),
            objective='Поднимитесь по уступам и пройдите крылатый дозор',
            platforms={floor(253,-1,0,34,18),floor(287.5,1,6,27,18),floor(318.5,3,0,27,18),floor(348,1,-6,24,22)},
            gaps={{minX=270,maxX=274},{minX=301,maxX=305},{minX=332,maxX=336}},
            enemies={enemy(-9,'Dragon',287,5,6),enemy(-10,'Dragon',320,7,0)}},
        {id='Watchforge',name='Кузница дозора',gateX=486,exit=exit(484,0),
            objective='Сломите последний наземный дозор',
            platforms={floor(423,-1,0,126,52)},
            enemies={enemy(-11,'Pig',386,3,-10),enemy(-12,'Pig',414,3,10),enemy(-13,'Pig',454,3,0)}},
        {id='Longbridge',name='Длинный мост',gateX=590,exit=exit(588,0),
            objective='Перепрыгните разлом и доберитесь до стража',
            flies={{id='bridge-fly-1',x=548,y=4.5,z=-5},{id='bridge-fly-2',x=554,y=4.5,z=5},
                {id='bridge-fly-3',x=568,y=4.5,z=-5},{id='bridge-fly-4',x=574,y=4.5,z=5}},
            platforms={floor(508,-1,0,44,26),floor(562.5,-1,0,55,26)},
            gaps={{minX=530,maxX=535,minZ=-13,maxZ=13}},enemies={}},
    },
    boss={position={x=628,y=3,z=0},platform=floor(641,-1,0,102,70),gateX=668,
        exit={minX=670,maxX=690,minY=1,maxY=10,minZ=-12,maxZ=12},pad={x=680,y=.09,z=0,w=16,d=24}},
    -- Measured Roblox-scale tuning, not claims about NES timing or distances.
    bounds={minX=-90,maxX=700,minZ=-90,maxZ=90},
}
