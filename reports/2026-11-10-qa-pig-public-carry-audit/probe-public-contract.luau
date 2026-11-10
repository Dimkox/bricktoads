local Fixture=require('./fixture')
local f=Fixture.new(15);local d,s,w=f.director,f.session,f.world
local sequence={}
for cycle=1,3 do
 local at=(cycle-1)*1.55
 f.step(at+.01);assert(d.enemies[-5].windup,'Ordinary Pig NPC starts its own Jab')
 assert(d.carry:interaction(1).available,'Grounded facing corner qualifies for real carry')
 assert(f.punch(at+.02)=='OK','Normal public Punch accepts pickup')
 f.step(at+.16);assert(d.carry:stateFor(-5)=='Carried'and w.links[-5]==1,'Same Pig body captured')
 assert(d.enemies[-5].windup==nil,'Capture cancels actual pending Pig Jab')
 f.step(at+.65);assert(f.punch(at+.65)=='OK','Next normal public Punch accepts throw')
 local immediate=d.enemies[-5].rawLife;assert(immediate==11,'Real EnemyThrow subtracts4 from15')
 f.step(at+1.51);local recovered=d.enemies[-5].rawLife;assert(recovered==15 and not d.enemies[-5].dead,'Normal flight completion recovers11 back to15')
 assert(s.state.heroes[1].actorId==f.heroId and s.state.heroes[1].attempt==1 and s.state.heroes[1].respawns==3 and s.combat[1].rawLife==47,'No actor/resource writes or costs')
 assert(d.enemies[-5].actorId==f.pigId,'No Pig replacement')
 sequence[#sequence+1]=immediate..'->'..recovered
end
print('PASS raw15 ordinary pickup/throw x3:',table.concat(sequence,','),'PigLife',d.enemies[-5].rawLife,'PigDead',d.enemies[-5].dead)
local low=Fixture.new(3);low.step(.01);assert(low.punch(.02)=='OK');low.step(.16)
assert(low.director.carry:stateFor(-5)=='Carried');low.step(.65);assert(low.punch(.65)=='OK')
assert(low.director.enemies[-5].dead and low.director.enemies[-5].rawLife==0,'Existing throw underflow kills a raw3 Pig')
assert(low.session.combat[1].rawLife==47 and low.session.state.heroes[1].respawns==3,'Finisher uses normal source controls')
print('PASS raw3 ordinary Punch pickup -> Punch throw -> same Pig EnemyDeath, hero47/attempt1/stock3')
local head=Fixture.new(3);head.world.positions[1].y=8
assert(not head.director.carry:interaction(1).available,'Historical Pig-head height cannot use a ground grab finisher')
local away=Fixture.new(3);away.world.front[1]={x=.44514727263538223,z=.8954573723328658}
assert(not away.director.carry:interaction(1).available,'Facing guard remains authoritative')
print('PASS head-height and wrong-facing carry guards retained')
