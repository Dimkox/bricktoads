return function(Feedback)
    local passed=0
    local function test(name,fn) fn();passed+=1;print('PASS '..name) end
    local function event(seq,kind,extra)
        local row={seq=seq,kind=kind or 'Hit',now=seq,levelEpoch=1,slot=1,actorId='a',attacker=2,blocked=false}
        for k,v in pairs(extra or {}) do row[k]=v end;return row
    end
    local function data(seq,events,extra)
        local row={groupId='g',runId='r',levelEpoch=1,now=seq,snapshotSeq=seq+1,mine=1,heroes={{slot=1,actorId='a',attempt=1}},
            feedback={latestSeq=seq,events=events or {}}}
        for k,v in pairs(extra or {}) do row[k]=v end;return row
    end
    test('first sync and reconnect baseline never replay old combat',function()
        local f=Feedback.new();assert(#f:sync(data(5,{event(5)}))==0)
        local r=f:sync(data(6,{event(5),event(6)}));assert(#r==1 and r[1].kind=='Hit' and r[1].text=="DAMAGE TAKEN")
        assert(#Feedback.new():sync(data(6,{event(6)}))==0)
    end)
    test('repeated stale and shuffled packets cannot duplicate or reverse confirmed feedback',function()
        local f=Feedback.new();f:sync(data(0))
        local rows=f:sync(data(3,{event(3,'AttackMiss'),event(2,'Hit'),event(2,'Hit')}))
        assert(#rows==2 and rows[1].seq==2 and rows[2].seq==3 and rows[2].text=="MISS")
        assert(#f:sync(data(2,{event(2)}))==0 and #f:sync(data(3,{event(3)}))==0)
    end)
    test('group run and level boundaries cannot attach old feedback to another body',function()
        local f=Feedback.new();f:sync(data(0))
        assert(#f:sync(data(10,{event(10)},{groupId='g2'}))==0)
        assert(#f:sync(data(11,{event(11)},{groupId='g2',runId='r2'}))==0)
        local current=data(12,{event(12,'Hit',{levelEpoch=1})},{groupId='g2',runId='r2',levelEpoch=2})
        assert(#f:sync(current)==0)
        local body=data(13,{event(13,'Hit',{actorId='old',levelEpoch=2})},
            {groupId='g2',runId='r2',levelEpoch=2,heroes={{slot=1,actorId='new',attempt=2}}})
        assert(#f:sync(body)==0)
    end)
    test('blocked damage and confirmed interactions have distinct finite text',function()
        local f=Feedback.new();f:sync(data(0))
        local rows=f:sync(data(4,{event(1,'Hit',{blocked=true}),event(2,'ClubEquipped'),event(3,'FlyCaught'),event(4,'GuardianBallThrown')}))
        assert(#rows==4 and rows[1].text=="PROTECTED" and rows[2].text=="CLUB EQUIPPED"
            and rows[3].text=="HEALTH RESTORED" and rows[4].text=="BALL THROWN")
    end)
    test('a gap emits only remaining recent rows with bounded cursor memory',function()
        local f=Feedback.new();f:sync(data(0));local events={}
        for i=9,20 do events[#events+1]=event(i) end
        local rows=f:sync(data(20,events));assert(#rows==4,'Include only the last3seconds and its exact boundary')
        assert(f.cursor==20 and f.seen==nil)
    end)
    test('malformed and foreign actor rows cannot become client effects',function()
        local f=Feedback.new();assert(#f:sync({feedback=true})==0);f:sync(data(0))
        assert(#f:sync(data(1,{event(1,'Unknown')}))==0)
        assert(#f:sync(data(2,{event(2,'Hit',{slot=2,attacker=3,actorId='other'})}))==0)
        assert(#f:sync(data(3,{event(3,'Hit',{now=math.huge})}))==0)
    end)
    test('short role hints follow server interaction and control state',function()
        assert(Feedback.hint({mine=1,interaction={available=true,label="GRAB"}})=='GRAB — action button')
        assert(Feedback.hint({enemyRole={template='Boss'}})=="FIRE: shoot at the heroes")
        assert(Feedback.hint({mine=1})=="ATTACK: strike or interact nearby")
    end)
    test('actual controlled running offers mega before an opportunistic pickup',function()
        local running={slot=1,actorId='a',status='Alive',connected=true,movementMode='Run'}
        local hint=Feedback.hint({mine=1,heroes={running},interaction={available=true,label='CLUB'}})
        assert(hint=="MEGA: running strike",'Running primary must not advertise a nearby pickup')
        assert(Feedback.hint({enemyRole={template='Sentry',status='Alive',connected=true,movementMode='Run'}})
            =="MEGA: running strike",'The controlled running enemy gets the same clear action hint')
        assert(Feedback.hint({mine=2,heroes={running},interaction={available=true,label='CLUB'}})
            =='CLUB — action button','Another actor running must not alter my action')
    end)
    test('mandatory held actions and boss controls keep priority over a stale run hint',function()
        local running={slot=1,status='Alive',connected=true,movementMode='Run'}
        assert(Feedback.hint({mine=1,heroes={running},interaction={available=true,carrying=true,label='THROW'}})
            =='THROW — action button')
        assert(Feedback.hint({mine=1,heroes={running},interaction={available=false,carrying=true,label="YOU WERE CAPTURED"}})
            =="YOU WERE CAPTURED")
        assert(Feedback.hint({enemyRole={template='Boss',status='Alive',movementMode='Run'}})
            =="FIRE: shoot at the heroes")
    end)
    test('zero hearts do not remove a still-living hero or ordinary actor from the HUD count',function()
        assert(Feedback.aliveHeroes({{status='Alive',hearts=0},{status='Alive',connected=false,hearts=5},
            {status='Alive',dying=true,hearts=0},{status='Eliminated',hearts=5}})==2)
        assert(Feedback.remainingEnemies({zoneIndex=2,enemies={{id=-1,zoneIndex=2,dead=false,hearts=0},
            {id=-2,zoneIndex=1,dead=false,hearts=3},{id=-3,zoneIndex=2,dead=true},
            {id=-99,zoneIndex=2,dead=false,hearts=3}}})==1)
    end)
    test('monotonic snapshot envelope prevents rollback and replay across groups and runs',function()
        local f=Feedback.new();f:sync(data(9,{event(9)},{snapshotSeq=1}))
        assert(#f:sync(data(10,{event(10)},{snapshotSeq=2}))==1)
        f:sync(data(20,{event(20)},{groupId='new',snapshotSeq=3}))
        local _,accepted=f:sync(data(9,{event(9)},{snapshotSeq=1}));assert(accepted==false)
        assert(#f:sync(data(10,{event(10)},{snapshotSeq=2}))==0)
        assert(#f:sync(data(11,{event(11)},{snapshotSeq=4}))==0,'A legitimate return baselines the old scope')
        assert(#f:sync(data(12,{event(12)},{snapshotSeq=5}))==1)
    end)
    test('Dragon transport has confirmed feedback and gate-aligned live counts',function()
        local f=Feedback.new();f:sync(data(0))
        local rows=f:sync(data(4,{event(1,'DragonMounted'),event(2,'DragonCaptured'),event(3,'DragonReleased'),event(4,'DragonFireHit')}))
        assert(#rows==4 and rows[1].text~=rows[2].text and rows[3].text~=rows[4].text)
        assert(Feedback.remainingEnemies({enemies={{id=-9,dragonMode='Mounted'},{id=-10,dragonMode='Disabled'}}})==1)
        assert(Feedback.hint({mine=1,interaction={available=false,carrying=true,label="YOU WERE CAPTURED"}})=="YOU WERE CAPTURED")
    end)
    local function action(id,code,expires,extra)
        local row={id=id,code=code or 'NOT_RUNNING',kind='Attack',groupId='g',runId='r',actorId='a',expiresAt=expires}
        for key,value in pairs(extra or {}) do row[key]=value end
        return row
    end
    test('owner action refusal is shown even when the public combat feed has not advanced',function()
        local f=Feedback.new();f:sync(data(0,nil,{snapshotSeq=1,serverNow=10}))
        local row=data(0,nil,{snapshotSeq=2,serverNow=11,actionFeedback=action(1,'NOT_RUNNING',11.9)})
        local shown=f:sync(row)
        assert(#shown==1 and shown[1].text=="Run first: double-tap a direction")
        assert(shown[1].kind=='ActionResult' and math.abs(shown[1].duration-.9)<.00001)
        row.snapshotSeq=3;row.serverNow=11.1
        assert(#f:sync(row)==0,'Move snapshots cannot replay or renew the same refusal')
    end)
    test('first sync reconnect actor and run changes baseline old action refusals',function()
        local f=Feedback.new()
        assert(#f:sync(data(0,nil,{snapshotSeq=1,serverNow=10,actionFeedback=action(8,'REACTION',11)}))==0)
        assert(#f:sync(data(0,nil,{snapshotSeq=2,serverNow=10,actionFeedback=action(9,'COOLDOWN',11)}))==1)
        assert(#f:sync(data(0,nil,{snapshotSeq=3,serverNow=10,heroes={{slot=1,actorId='new'}},
            actionFeedback=action(10,'HELD',11,{actorId='new'})}))==0)
        assert(#f:sync(data(0,nil,{snapshotSeq=4,serverNow=10,runId='new',actionFeedback=action(11,'THROWN',11,{runId='new'})}))==0)
        assert(#Feedback.new():sync(data(0,nil,{serverNow=10,actionFeedback=action(9,'COOLDOWN',11)}))==0)
    end)
    test('action feedback validates recipient context actor code kind expiry and monotonic id',function()
        local f=Feedback.new();f:sync(data(0,nil,{snapshotSeq=1,serverNow=10}))
        local variants={
            {groupId='foreign'},{runId='foreign'},{actorId='other'},{code='PRIVATE_STACK'},
            {kind='Move'},{expiresAt=10},{expiresAt=12},{expiresAt=math.huge},{id=0},{id=1.5},
        }
        local seq=1
        for _,extra in ipairs(variants) do
            seq+=1
            assert(#f:sync(data(0,nil,{snapshotSeq=seq,serverNow=10,actionFeedback=action(1,'REACTION',11,extra)}))==0)
        end
        seq+=1;assert(#f:sync(data(0,nil,{snapshotSeq=seq,serverNow=10,actionFeedback=action(1,'REACTION',11)}))==1,
            'Rejected foreign or malformed records must not poison the legitimate owner id')
        seq+=1;assert(#f:sync(data(0,nil,{snapshotSeq=seq,serverNow=10}))==0)
        seq+=1;assert(#f:sync(data(0,nil,{snapshotSeq=seq,serverNow=10,actionFeedback=action(1,'REACTION',11)}))==0,
            'A cleared action cannot be replayed if an old owner result reappears')
    end)
    test('delivery delay consumes action TTL and cannot restart an already expired refusal',function()
        local f=Feedback.new();f:sync(data(0,nil,{snapshotSeq=1,serverNow=10}))
        local shown=f:sync(data(0,nil,{snapshotSeq=2,serverNow=10,actionFeedback=action(1,'HELD',11.4)}),11.1)
        assert(#shown==1 and shown[1].duration<.301 and shown[1].duration>.299)
        assert(#f:sync(data(0,nil,{snapshotSeq=3,serverNow=11,actionFeedback=action(2,'THROWN',11.4)}),11.5)==0)
    end)
    test('enemy action feedback is private to its controlled body and independent of public feed validity',function()
        local f=Feedback.new();local extra={mine=false,heroes={},enemyRole={enemyId=-4,actorId='enemy'},
            snapshotSeq=1,serverNow=10,feedback=false}
        f:sync(data(0,nil,extra))
        extra.snapshotSeq=2;extra.actionFeedback=action(1,'THROWN',11,{actorId='enemy',kind='Jump'})
        local shown=f:sync(data(0,nil,extra));assert(#shown==1 and shown[1].kind=='ActionResult')
        extra.snapshotSeq=3;extra.enemyRole=false;extra.actionFeedback=action(2,'THROWN',11,{actorId='enemy'})
        assert(#f:sync(data(0,nil,extra))==0,'Spectators never receive a controlled actor action refusal')
    end)
    test('faulted party guidance describes a manual new game instead of stale live controls',function()
        local stopped={status='Faulted',fault=true,enemyRole={template='Boss'},interaction={carrying=true,label='THROW'}}
        assert(Feedback.hint(stopped)=="Party stopped · start again")
    end)
    print('CombatFeedback: '..passed..' PASS')
end
