local loaded,Audio=pcall(require,'../src/client/GameAudio')
assert(loaded,'GameAudio must implement confirmed client audio: '..tostring(Audio))
local Effects=require('../src/client/CombatEffects')
local passed,failed=0,0
local function check(name,fn)
    local ok,why=pcall(fn)
    if ok then passed+=1;print('PASS audio '..name) else failed+=1;print('FAIL audio '..name..': '..tostring(why)) end
end
local function copy(v) if type(v)~='table' then return v end;local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out end
local function snapshot(seq,events,latest)
    return {snapshotSeq=seq,groupId='party-a',runId='run-a',levelEpoch=1,status='Active',view='Playing',
        now=10+seq*.1,serverNow=10+seq*.1,mine=1,heroes={{slot=1,actorId='hero-1',status='Alive',attempt=1}},
        level={stage='Route'},feedback={latestSeq=latest or seq,events=events or {}}}
end
local function event(seq,kind,more)
    local row={seq=seq,kind=kind,now=10+seq*.1,levelEpoch=1,slot=1,actorId='hero-1'}
    for k,v in pairs(more or {}) do row[k]=v end;return row
end
local function setup(missing)
    local records,voices,fx={}, {}, {rows={},resets=0}
    function fx:emit(kind,row,data) self.rows[#self.rows+1]={kind=kind,event=row,groupId=data.groupId} end
    function fx:reset() self.resets+=1;self.rows={} end
    function fx:destroy() self.destroyed=true end
    function fx:setEnabled(value) self.enabled=value end
    function fx:setReducedFlash(value) self.reduced=value end
    local catalog={assets=missing and {} or {sfx='rbxassetid://101',music='rbxassetid://102'},cues={},music={}}
    for _,key in ipairs({'Hit','Shield','Miss','Club','Throw','Fly','Spawn','BossWarning','BossHit','Crash','Bomb','Victory','Defeat','Death','Equip','EnemyDeath'}) do
        catalog.cues[key]={start=1,finish=1.2,volume=.4}
    end
    for _,key in ipairs({'Level','Boss','Result','Lobby'}) do catalog.music[key]={start=2,finish=12,volume=.25} end
    local function createVoice(kind,index,asset)
        local v={kind=kind,index=index,asset=asset,playing=false,ready=true,plays=0,stops=0}
        function v:play(region,looped,volume,key)
            if not self.ready then return false end
            self.playing=true;self.plays+=1;self.region=region;self.volume=volume;self.looped=looped
            records[#records+1]={kind=self.kind,key=key,voice=self.index};return true
        end
        function v:stop() self.playing=false;self.stops+=1 end
        function v:destroy() self.destroyed=true;self.playing=false end
        function v:isLoaded() return self.ready end
        voices[#voices+1]=v;return v
    end
    return Audio.new({createVoice=createVoice,effects=fx},catalog),records,voices,fx,catalog
end
local function sfx(records,key) local n=0;for _,r in ipairs(records) do if r.kind=='sfx' and (not key or r.key==key) then n+=1 end end;return n end
check('first sync consumes history and repeated or older snapshots cannot replay it',function()
    local a,rows=setup();a:sync(snapshot(1,{event(1,'Hit')}));assert(sfx(rows)==0)
    a:sync(snapshot(2,{event(1,'Hit'),event(2,'Hit')}));assert(sfx(rows,'Hit')==1)
    a:sync(snapshot(2,{event(2,'Hit')}));a:sync(snapshot(1,{event(1,'Hit')}));assert(sfx(rows)==1)
end)
check('stale future foreign-actor old-level and duplicate feed rows are rejected',function()
    local a,rows=setup();a:sync(snapshot(1))
    local old=event(2,'Hit',{now=1});local future=event(3,'Hit',{now=100})
    local wrong=event(4,'Hit',{actorId='retired'});local epoch=event(5,'Hit',{levelEpoch=2})
    local good=event(6,'Hit');local s=snapshot(7,{old,future,wrong,epoch,good,copy(good)},7)
    a:sync(s);assert(sfx(rows)==1)
end)
check('group run level and replacement actor reset voices and establish new baselines',function()
    local a,rows,voices,fx=setup();a:sync(snapshot(1));a:sync(snapshot(2,{event(2,'Hit')}))
    local n=sfx(rows);local s=snapshot(3,{event(3,'Hit')});s.groupId='party-b';a:sync(s);assert(sfx(rows)==n)
    s=snapshot(4,{event(4,'Hit')});s.groupId='party-b';s.runId='run-b';a:sync(s);assert(sfx(rows)==n)
    s=snapshot(5,{event(5,'Hit',{levelEpoch=2})});s.groupId='party-b';s.runId='run-b';s.levelEpoch=2;a:sync(s);assert(sfx(rows)==n)
    s=snapshot(6,{event(6,'Hit',{actorId='hero-2',levelEpoch=2})});s.groupId='party-b';s.runId='run-b';s.levelEpoch=2;s.heroes[1].actorId='hero-2';a:sync(s)
    assert(sfx(rows)==n and fx.resets>=5);for _,v in ipairs(voices) do assert(v.stops>0) end
end)
check('fresh same-context owner respawn plays once while replaced-body history stays silent',function()
    local a,rows,_,fx=setup();a:sync(snapshot(1))
    local s=snapshot(2);s.heroes[1].status='AwaitingRespawn';s.heroes[1].actorId=nil;a:sync(s)
    local before=sfx(rows)
    s=snapshot(3,{event(2,'Hit'),event(3,'CommitSpawn',{actorId='hero-2',attempt=2})})
    s.heroes[1].actorId='hero-2';s.heroes[1].attempt=2;a:sync(s)
    assert(sfx(rows)==before+1 and sfx(rows,'Spawn')==1 and #fx.rows==1 and fx.rows[1].kind=='spawn')
    a:sync(snapshot(4,{event(3,'CommitSpawn',{actorId='hero-2',attempt=2})}));assert(sfx(rows,'Spawn')==1)
end)
check('respawn exception rejects stale mismatched and new-context spawn history',function()
    for _,mode in ipairs({'stale','attempt','actor','group','level','first'}) do
        local a,rows=setup();if mode~='first' then a:sync(snapshot(1)) end
        local e=event(2,'CommitSpawn',{actorId='hero-2',attempt=2})
        local s=snapshot(2,{e});s.heroes[1].actorId='hero-2';s.heroes[1].attempt=2
        if mode=='stale' then e.now=1 elseif mode=='attempt' then e.attempt=1 elseif mode=='actor' then e.actorId='retired'
        elseif mode=='group' then s.groupId='party-b' elseif mode=='level' then s.levelEpoch=2;e.levelEpoch=2 end
        a:sync(s);assert(sfx(rows,'Spawn')==0,mode)
    end
end)
check('SFX pool stays at eight voices during bursts and music is separate',function()
    local a,rows,voices=setup();a:sync(snapshot(1))
    for seq=2,5 do local ev={};for i=1,12 do ev[i]=event((seq-2)*12+i+1,'Hit',{now=10+seq*.1}) end
        a:sync(snapshot(seq,ev,(seq-1)*12+1)) end
    assert(sfx(rows)==48 and #voices==9);local seen={};for _,r in ipairs(rows) do if r.kind=='sfx' then seen[r.voice]=true end end
    local count=0;for _ in pairs(seen) do count+=1 end;assert(count==8)
end)
check('mute consumes events without catch-up and music can be muted independently',function()
    local a,rows,voices,fx=setup();a:sync(snapshot(1));a:setMuted(true);a:sync(snapshot(2,{event(2,'Hit')}));assert(sfx(rows)==0 and #fx.rows==1)
    a:setMuted(false);a:sync(snapshot(3,{event(2,'Hit')}));assert(sfx(rows)==0)
    a:setMusicMuted(true);a:sync(snapshot(4,{event(4,'Hit')}));assert(sfx(rows)==1)
    for _,v in ipairs(voices) do if v.kind=='music' then assert(not v.playing) end end
end)
check('invalid groups and unconfigured assets cannot produce audio or report ready',function()
    local a,rows=setup();local s=snapshot(1);s.groupId=nil;a:sync(s);assert(#rows==0)
    local b,brows,bvoices=setup(true);b:sync(snapshot(1));b:sync(snapshot(2,{event(2,'Hit')}));assert(#brows==0 and #bvoices==0 and not b:diagnostics().ready)
end)
check('production catalog sends uploaded atlas regions through the real selection policy',function()
    local actual=require('../src/shared/AudioCatalog')
    local a,_,voices,fx=setup()
    a:destroy()
    local captured={}
    local function voice(kind,index,id)
        assert(type(id)=='string' and id:match('^rbxassetid://[1-9]%d*$'))
        return {play=function(_,row,loop,volume,key) captured[#captured+1]={kind=kind,row=row,loop=loop,key=key};return true end,
            stop=function() end,destroy=function() end,isLoaded=function() return true end}
    end
    a=Audio.new({createVoice=voice,effects=fx},actual);a:sync(snapshot(1));a:sync(snapshot(2,{event(2,'Hit')}))
    assert(#captured==2 and captured[1].key=='Level' and captured[1].loop==true)
    assert(captured[2].key=='Hit' and math.abs(captured[2].row.start-.18)<.00001 and math.abs(captured[2].row.finish-.4)<.00001)
end)
check('asset loading does not defer an impact into a later snapshot',function()
    local a,rows,voices=setup();a:sync(snapshot(1));for _,v in ipairs(voices) do v.ready=false end
    a:sync(snapshot(2,{event(2,'Hit')}));for _,v in ipairs(voices) do v.ready=true end
    a:sync(snapshot(3,{event(2,'Hit')}));assert(sfx(rows)==0)
end)
check('confirmed cue meanings and effects use only accepted fresh events',function()
    local a,rows,_,fx=setup();a:sync(snapshot(1))
    a:sync(snapshot(7,{event(2,'Hit',{blocked=true}),event(3,'Hit',{action='Club'}),event(4,'FlyCaught'),event(5,'EnemyThrown'),event(6,'BossWarning'),event(7,'RunResult',{result='Won'})}))
    for _,key in ipairs({'Shield','Club','Fly','Throw','BossWarning','Victory'}) do assert(sfx(rows,key)==1,key) end
    assert(#fx.rows==5)
end)
check('club and dragon-fire supplemental records cannot duplicate the confirmed impact',function()
    local a,rows,_,fx=setup();a:sync(snapshot(1))
    a:sync(snapshot(5,{event(2,'Hit',{action='Club'}),event(3,'ClubSwingHit'),
        event(4,'EnemyHit',{action='DragonFire',slot=-2,actorId='boar-1'}),event(5,'DragonFireHit')}))
    assert(sfx(rows)==2 and sfx(rows,'Club')==1 and sfx(rows,'Hit')==1 and #fx.rows==2)
end)
check('music changes with authoritative boss and result context only once',function()
    local a,rows=setup();a:sync(snapshot(1));a:sync(snapshot(2));local b=snapshot(3);b.level={stage='Boss',bossType='DarkQueen',boss={bossDefeated=false}};a:sync(b)
    b=snapshot(4);b.status='Won';a:sync(b);local keys={};for _,r in ipairs(rows) do if r.kind=='music' then keys[#keys+1]=r.key end end
    assert(table.concat(keys,',')=='Level,Boss,Result')
end)
check('hero death transition produces one death cue and no duplicate Hit',function()
    local a,rows=setup();a:sync(snapshot(1));local s=snapshot(2,{event(2,'Hit')});s.heroes[1].dying=true;a:sync(s)
    s=snapshot(3);s.heroes[1].status='AwaitingRespawn';s.heroes[1].actorId=nil;a:sync(s);a:sync(snapshot(4))
    assert(sfx(rows,'Death')==1 and sfx(rows,'Hit')==1)
end)
check('campaign boss snapshot transitions fill absent public hit and warning cues',function()
    local a,rows=setup();local s=snapshot(1);s.level={stage='Boss',boss={bossState='Ready',rawLife=30,progress=0}};a:sync(s)
    s=snapshot(2);s.level={stage='Boss',boss={bossState='Tell',bossAttack='Sweep',rawLife=24,progress=0}};a:sync(s);a:sync(s)
    assert(sfx(rows,'BossWarning')==1 and sfx(rows,'BossHit')==1)
end)
check('destroy stops every voice and ignores future snapshots',function()
    local a,rows,voices,fx=setup();a:sync(snapshot(1));a:destroy();local n=#rows;a:sync(snapshot(2,{event(2,'Hit')}));assert(#rows==n and fx.destroyed)
    for _,v in ipairs(voices) do assert(v.destroyed and not v.playing) end
end)
check('cosmetic particles are capped and cleared when disabled or scope changes',function()
    local live,created=0,{}
    local e=Effects.new({resolvePosition=function() return {x=1,y=2,z=3} end,createParticle=function(spec)
        assert(spec.canCollide==false and spec.canQuery==false and spec.canTouch==false and spec.anchored==true)
        live+=1;local h={dead=false};function h:destroy() if not self.dead then self.dead=true;live-=1 end end
        created[#created+1]={spec=spec,handle=h};return h
    end})
    local s=snapshot(1);for _=1,20 do e:emit('shield',event(1,'Hit'),s) end
    assert(live==24 and e:diagnostics().live==24)
    s.now=12;e:sync(s);assert(live==0)
    e:emit('heal',event(2,'FlyCaught'),s);assert(live>0);e:setEnabled(false);assert(live==0)
    e:emit('hit',event(3,'Hit'),s);assert(live==0);e:setEnabled(true);e:emit('hit',event(4,'Hit'),s);e:reset();assert(live==0)
    e:destroy();e:emit('hit',event(5,'Hit'),s);assert(live==0)
end)
check('effects require a resolvable actor in the selected group',function()
    local created=0;local e=Effects.new({resolvePosition=function() return nil end,createParticle=function() created+=1 end})
    e:emit('hit',event(1,'Hit'),snapshot(1));assert(created==0)
end)
print(string.format('Audio/FX contracts: %d passed, %d failed',passed,failed))
assert(failed==0,'audio/FX policy regression')
