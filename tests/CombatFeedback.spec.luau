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
        local r=f:sync(data(6,{event(5),event(6)}));assert(#r==1 and r[1].kind=='Hit' and r[1].text=='ПОЛУЧЕН УРОН')
        assert(#Feedback.new():sync(data(6,{event(6)}))==0)
    end)
    test('repeated stale and shuffled packets cannot duplicate or reverse confirmed feedback',function()
        local f=Feedback.new();f:sync(data(0))
        local rows=f:sync(data(3,{event(3,'AttackMiss'),event(2,'Hit'),event(2,'Hit')}))
        assert(#rows==2 and rows[1].seq==2 and rows[2].seq==3 and rows[2].text=='ПРОМАХ')
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
        assert(#rows==4 and rows[1].text=='ЗАЩИТА' and rows[2].text=='ДУБИНА В РУКАХ'
            and rows[3].text=='ЗДОРОВЬЕ ВОССТАНОВЛЕНО' and rows[4].text=='ШАР БРОШЕН')
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
        assert(Feedback.hint({mine=1,interaction={available=true,label='СХВАТИТЬ'}})=='СХВАТИТЬ — кнопка действия')
        assert(Feedback.hint({enemyRole={template='Boss'}})=='ОГОНЬ: стреляйте в героев')
        assert(Feedback.hint({mine=1})=='УДАР: атака или действие рядом')
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
    print('CombatFeedback: '..passed..' PASS')
end
