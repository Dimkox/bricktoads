local Pilot=require('../../tools/qa/campaign_combat_pilot')
local Baseline=require('./pre-queen-combat-4F')
local Definition=require('../../src/server/gameplay/CampaignDefinition')
local Config=require('../../src/server/gameplay/GameConfig')(require('../../src/stand/server/Config'),Definition.build(13,1158731273))
local function fixture()
 local p={x=0,y=3,z=0};local q={x=-4,y=3,z=0}
 local boss={kind='DarkQueen',state='Ready',readyAt=100.25,attackSerial=0,arena={minX=-20,maxX=20,minZ=-20,maxZ=20},enemies={[-99]={boss=true,rawLife=15,progress=0}}}
 local c={slot=1,now=100,dt=.133,definition=Definition.build(13,1158731273),
  session={state={status='Active',runId='queen-gates',levelEpoch=13,heroes={[1]={status='Alive',connected=true,held=false,actorId='hero1',attempt=1,respawns=3}}},config=Config,combat={[1]={rawLife=47,nextAttack=0}}},
  director={stage='Boss',boss=boss,enemies=boss.enemies,ordinary={enemies={}}},modes={mode='Finale',actors={[1]={finished=true}}},
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
local function publicOnly(out)
 for key in pairs(out)do check(key=='x'or key=='z'or key=='run'or key=='jump'or key=='primary'or key=='evasion','No target/state/resource metadata in the QA output')end
 check(not out.primary and not out.jump,'Evasion does not invent attacks or jumps')
 check(out.x==out.x and out.z==out.z and out.x*out.x+out.z*out.z<=1.000001,'Finite normalized ordinary axes')
end
do
 local c=fixture();freeze(c);local out=Pilot.plan(c)
 check(out.run and out.evasion and out.z==1 and out.x==0,'Ready establishes Sweep momentum before Tell')
 check(c.session.combat[1].rawLife==47 and c.session.state.heroes[1].respawns==3,'Frozen game/resource state unchanged')
 publicOnly(out)
end
for _,reset in ipairs({'actor','attempt','level','run','boss','serial','session','slot'})do
 local c,p,q,b=fixture();check(Pilot.plan(c).z==1,'Initial side chosen')
 p.z=15;q.z=15;check(Pilot.plan(c).z==0,'Same serial holds near edge without reversing')
 if reset=='actor'then c.session.state.heroes[1].actorId='hero2'
 elseif reset=='attempt'then c.session.state.heroes[1].attempt=2
 elseif reset=='level'then c.session.state.levelEpoch=14
 elseif reset=='run'then c.session.state.runId='queen-new-run'
 elseif reset=='boss'then c.director.boss=table.clone(b)
 elseif reset=='serial'then b.attackSerial=2
 elseif reset=='session'then c.session=table.clone(c.session)
 else
  c.session.state.heroes[2]=table.clone(c.session.state.heroes[1]);c.session.combat[2]=table.clone(c.session.combat[1])
  c.world.actors[2]=c.world.actors[1];c.modes.actors[2]=c.modes.actors[1];c.slot=2
  c.world.position=function(_,id)return id>0 and p or q end
 end
 check(Pilot.plan(c).z<-.99,'Fresh '..reset..' recomputes an inward side')
end
do
 local c,p,_,b=fixture();check(Pilot.plan(c).z==1,'Pre-Tell Sweep side established')
 b.state='Tell';b.attackSerial=1;b.attack={name='Sweep',origin={x=-4,y=3,z=0},aim={x=1,z=0},move={reach=8,width=4,active=.25}}
 check(Pilot.plan(c).z==1,'Same anticipated Sweep serial preserves momentum through Tell')
 p.z=8;local out=Pilot.plan(c)
 check(out.x==0 and out.z==0 and not out.primary,'Already-clear Sweep position holds instead of approaching')
 publicOnly(out)
end
do
 local c,p,_,b=fixture();b.attackSerial=1
 check(Pilot.plan(c).x==1,'Ready Spin selects available origin refuge')
 b.state='Tell';b.attackSerial=2;b.attack={name='Spin',origin={x=-4,y=3,z=0},aim={x=1,z=0},move={orbit=8,radius=3.2,active=1.8}}
 check(Pilot.plan(c).x==1,'Anticipated Spin refuge persists into Tell')
 p.x=10.3;local out=Pilot.plan(c)
 check(out.x==0 and out.z==0,'Outside Spin origin envelope holds through Tell')
 b.state='Active';check(Pilot.plan(c).x==0,'Outside Spin refuge also holds through Active')
 publicOnly(out)
end
do
 local c,p,q,b=fixture();p.x=14.2;q.x=0;b.arena={minX=-40,maxX=40,minZ=-40,maxZ=40}
 b.state='Tell';b.attackSerial=2;b.attack={name='Spin',origin={x=0,y=3,z=0},aim={x=1,z=0},move={orbit=8,radius=3.2,active=1.8}}
 check(Baseline.plan(c).x<0,'Retained baseline explicitly reenters from the clear Spin envelope')
 local out=Pilot.plan(c);check(out.x==0 and out.z==0,'New helper removes the demonstrated inward fallback')
end
for _,gate in ipairs({'pending','reaction','dead','offline','held','air','anchored','platformStand','noRoot','noHumanoid','courseStage','unfinishedRace','otherBoss','noArena','noEarlyReady','carried','capturedDragon','mountedDragon','closed','result'})do
 local c,_,_,b=fixture()
 if gate=='pending'then c.session.combat[1].attack={at=101}
 elseif gate=='reaction'then c.session.combat[1].reactionEnd=101
 elseif gate=='dead'then c.session.combat[1].deathAt=101
 elseif gate=='offline'then c.session.state.heroes[1].connected=false
 elseif gate=='held'then c.session.state.heroes[1].held=true
 elseif gate=='air'then c.world.actors[1].humanoid.FloorMaterial='Air'
 elseif gate=='anchored'then c.world.actors[1].root.Anchored=true
 elseif gate=='platformStand'then c.world.actors[1].humanoid.PlatformStand=true
 elseif gate=='noRoot'then c.world.actors[1].root=nil
 elseif gate=='noHumanoid'then c.world.actors[1].humanoid=nil
 elseif gate=='courseStage'then c.director.stage='Route'
 elseif gate=='unfinishedRace'then c.modes.mode='Race';c.modes.actors[1].finished=false
 elseif gate=='otherBoss'then b.kind='BigBlag'
 elseif gate=='noArena'then b.arena=nil
 elseif gate=='noEarlyReady'then b.readyAt=101
 elseif gate=='carried'then c.director.carry={holders={[1]=-3},states={[-3]={id=-3,mode='Carried'}}}
 elseif gate=='capturedDragon'then c.director.ordinary.dragons={heroes={[1]={mode='Captured'}}}
 elseif gate=='mountedDragon'then c.director.ordinary.dragons={heroes={[1]={mode='Mounted'}}}
 elseif gate=='closed'then c.director.closed=true
 else c.director.result='Won'end
 freeze(c);check(same(Pilot.plan(c),Baseline.plan(c)),'4F behavior retained at '..gate..' gate')
end
print('PASS integrated Queen guards/state/read-only',count)
