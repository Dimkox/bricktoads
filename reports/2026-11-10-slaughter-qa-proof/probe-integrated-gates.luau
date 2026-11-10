local Pilot=require('../../tools/qa/campaign_combat_pilot')
local Baseline=require('./baseline-combat')
local Definition=require('../../src/server/gameplay/CampaignDefinition')
local Config=require('../../src/server/gameplay/GameConfig')(require('../../src/stand/server/Config'),Definition.build(10,1158731273))
local function fixture()
 local p={x=0,y=3,z=0};local q={x=-4,y=3,z=0}
 local boss={kind='GeneralSlaughter',state='Ready',readyAt=100.25,attackSerial=1,arena={minX=-20,maxX=20,minZ=-20,maxZ=20},enemies={[-99]={boss=true,rawLife=255,progress=0}}}
 local c={slot=1,now=100,dt=.133,definition=Definition.build(10,1158731273),
  session={state={status='Active',runId='gates',levelEpoch=1,heroes={[1]={status='Alive',connected=true,actorId='hero1',attempt=1,respawns=3}}},config=Config,combat={[1]={rawLife=47,nextAttack=0}}},
  director={stage='Boss',boss=boss,enemies=boss.enemies,ordinary={enemies={}}},modes={mode='Race',actors={[1]={finished=true}}},
  world={actors={[1]={root={Parent=true,Anchored=false,CFrame={LookVector={X=-1,Z=0}},AssemblyLinearVelocity={X=0,Y=0,Z=24}},humanoid={Health=100,PlatformStand=false,FloorMaterial='Slate'}}},position=function(_,id)return id==1 and p or q end}}
 return c,p,q,boss
end
local function freeze(t,seen)
 if type(t)~='table'or table.isfrozen(t)then return t end;seen=seen or{};if seen[t]then return t end;seen[t]=true
 for _,v in pairs(t)do freeze(v,seen)end;return table.freeze(t)
end
local count=0
local function check(v,m)assert(v,m);count+=1 end
local function same(a,b)
 for k,v in pairs(a)do if b[k]~=v then return false end end
 for k,v in pairs(b)do if a[k]~=v then return false end end
 return true
end
do
 local c=fixture();freeze(c);local out=Pilot.plan(c)
 check(out.run and out.evasion and out.z==1 and out.x==0 and not out.primary,'Frozen read-only source context establishes ordinary perpendicular momentum')
 check(c.session.combat[1].rawLife==47 and c.session.state.heroes[1].respawns==3,'Original resources remain unchanged')
 check(out.aimX==nil and out.target==nil,'No target/hit/state metadata added to public plan')
end
for _,reset in ipairs({'actor','attempt','level','boss','serial'})do
 local c,p,q,b=fixture();check(Pilot.plan(c).z==1,'Initial side chosen')
 p.z=15;q.z=15;check(Pilot.plan(c).z==0,'Same serial holds before edge rather than reversing')
 if reset=='actor'then c.session.state.heroes[1].actorId='hero2'
 elseif reset=='attempt'then c.session.state.heroes[1].attempt=2
 elseif reset=='level'then c.session.state.levelEpoch=2
 elseif reset=='boss'then local replacement=table.clone(b);c.director.boss=replacement
 else b.attackSerial=3 end
 check(Pilot.plan(c).z<-.99,'Fresh '..reset..' chooses safe inward side rather than inheriting previous body/serial')
end
do
 local c,p,_,b=fixture();check(Pilot.plan(c).z==1,'Pre-Tell momentum established')
 b.state='Tell';b.attackSerial=2;b.attack={origin={x=-4,y=3,z=0},aim={x=1,z=0},move={reach=7,width=3.5,active=.2}}
 check(Pilot.plan(c).z==1,'Same anticipated serial keeps momentum through actual source Tell')
 p.z=8;local out=Pilot.plan(c)
 check(out.x==0 and out.z==0 and not out.primary,'Already safe Tell position does not approach invulnerable boss')
end
for _,gate in ipairs({'pending','reaction','air','anchored','platformStand','unfinishedRace','otherBoss','noArena','noEarlyReady','carried','capturedDragon','mountedDragon'})do
 local c,_,_,b=fixture()
 if gate=='pending'then c.session.combat[1].attack={at=101}
 elseif gate=='reaction'then c.session.combat[1].reactionEnd=101
 elseif gate=='air'then c.world.actors[1].humanoid.FloorMaterial='Air'
 elseif gate=='anchored'then c.world.actors[1].root.Anchored=true
 elseif gate=='platformStand'then c.world.actors[1].humanoid.PlatformStand=true
 elseif gate=='unfinishedRace'then c.modes.actors[1].finished=false
 elseif gate=='otherBoss'then b.kind='BigBlag'
 elseif gate=='noArena'then b.arena=nil
 elseif gate=='carried'then c.director.carry={holders={[1]=-3},states={[-3]={id=-3,mode='Carried'}}}
 elseif gate=='capturedDragon'then c.director.ordinary.dragons={heroes={[1]={mode='Captured'}}}
 elseif gate=='mountedDragon'then c.director.ordinary.dragons={heroes={[1]={mode='Mounted'}}}
 else b.readyAt=101 end
 freeze(c);check(same(Pilot.plan(c),Baseline.plan(c)),'Original behavior preserved at '..gate..' gate')
end
print('PASS integrated Slaughter gates/state/read-only',count)
