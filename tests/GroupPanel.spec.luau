return function(GroupPanel)
    local passed=0
    local function test(name,fn) fn();passed+=1;print('PASS '..name) end
    local function panel()
        local sent={}
        local p=setmetatable({data={groupId='g'},rows={},overlay={Visible=true},menuCard={},hudButton={},
            list={},menuCurrent={},current={},menuButton={},empty={},create={},notice={},
            pending='Create',pendingAt=-1e10,createRequestId='request',
            colors={lime=1,ink=2,card=3,muted=4,text=5},sendIntent=function(row) sent[#sent+1]=row end},GroupPanel)
        return p,sent
    end
    local function snapshot(state)
        return {groupId='g',groupName="Team",status='Lobby',groups={},canCreateGroup=true,
            serverTransfer=state and {state=state} or nil}
    end
    test('optional pending server transfer keeps the existing request busy beyond local acknowledgement timeout',function()
        local p,sent=panel();p:update(snapshot('Pending'));p:step()
        assert(p.pending=='Server' and #sent==0)
        assert(not p.create.Active and p.notice.Text=="Moving to a new server…")
        assert(not p.notice.Text:find('request',1,true))
    end)
    test('failed optional server transfer gives a readable retry through the existing create button',function()
        local p=panel();p:update(snapshot('Pending'));p:update(snapshot('Failed'))
        assert(not p.pending and not p.createRequestId and p.create.Active)
        assert(p.create.Text=="Try again" and p.notice.Text=="Could not move. Try again.")
    end)
    test('without a transfer field the original bounded local request still refreshes once',function()
        local p,sent=panel();p:update(snapshot());p:step()
        assert(not p.pending and #sent==1 and sent[1].kind=='Sync')
        assert(p.create.Text=="Create team")
    end)
    print('GroupPanel: '..passed..' PASS')
end
