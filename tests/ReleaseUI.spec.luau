return function(Catalog,Localization,BossQueuePanel,GroupPanel)
    local passed,failed=0,0
    local function test(name,fn)
        local ok,err=pcall(fn)
        if ok then passed+=1;print('PASS '..name) else failed+=1;print('FAIL '..name..': '..tostring(err)) end
    end
    local function eq(a,b) assert(a==b,'expected '..tostring(b)..', got '..tostring(a)) end
    local function localize(locale)
        local service={RobloxLocaleId=locale}
        local function create()
            local table={}
            function table:SetEntries(entries) self.entries=entries end
            function table:GetTranslator(id)
                return {FormatByKey=function(_,key,args)
                    for _,row in ipairs(self.entries) do if row.Key==key then
                        return ((row.Values[id] or row.Source):gsub('{([%w_]+):?[%w_]*}',function(k) return tostring(args[k]) end))
                    end end
                    error('Unknown translation')
                end}
            end
            return table
        end
        local adapter=Localization.new(Catalog,service,create)
        T=function(source,args) return adapter:text(source,args) end
    end
    local function data(index,status,enemy)
        return {status=status,view='Menu',enemyRole=enemy,campaign={index=index,count=13,complete=index==13 and status=='Won'},
            level={campaignIndex=index,campaignCount=13,levelName=({[1]='Flooded Causeway',[8]='Machine Ascent',[13]='Last Eclipse'})[index],bossMechanic='Campaign'}}
    end
    for _,locale in ipairs({'en-us','ru-ru','xx-zz'}) do
        localize(locale)
        test(locale..' final success names the campaign instead of the Causeway',function()
            snapshot=data(13,'Won');productionMenu()
            eq(title.Text,T('Campaign complete'))
            eq(resultTitle.Text,T('CAMPAIGN COMPLETE!'))
            if locale=='ru-ru' then eq(title.Text,'Кампания пройдена');eq(resultTitle.Text,'КАМПАНИЯ ПРОЙДЕНА!') end
            assert(not resultDetail.Text:find(T('Causeway Guardian'),1,true))
            assert(resultDetail.Text:find('13',1,true))
        end)
        test(locale..' stage eight defeat identifies the actual stage and manual restart',function()
            snapshot=data(8,'Lost');productionMenu()
            eq(title.Text,T('Machine Ascent'))
            assert(resultDetail.Text:find(T('Machine Ascent'),1,true))
            eq(intro.Text,T('Press “New game” to start the next attempt.'))
        end)
        test(locale..' stage one defeat and legacy snapshots remain readable',function()
            snapshot=data(1,'Lost');productionMenu();eq(title.Text,T('Flooded Causeway'))
            snapshot={status='Lost'};productionMenu();eq(title.Text,T('Flooded Causeway'))
            snapshot=nil;productionMenu();eq(title.Text,T('Flooded Causeway'))
        end)
        test(locale..' enemy final result and later boss personal menu use actual context',function()
            snapshot=data(13,'Won',{template='Boss',bossType='DarkQueen',name='Dark Queen',status='Dead'});productionMenu()
            eq(resultTitle.Text,T('HEROES COMPLETED THE CAMPAIGN'));eq(resultTitle.TextColor3,C.red)
            snapshot=data(8,'Active',{template='Boss',bossType='RoboManus',name='Robo-Manus',status='Dead'});productionMenu()
            assert(intro.Text:find(T('Robo-Manus'),1,true));assert(not intro.Text:find(T('Causeway Guardian'),1,true))
            snapshot=data(8,'Lost',{template='Enemy',status='Dead'});productionMenu()
            eq(resultTitle.TextColor3,C.lime);assert(resultDetail.Text:find(T('Machine Ascent'),1,true))
        end)
        test(locale..' fault stays a manually restarted stopped party',function()
            snapshot={status='Faulted'};productionMenu();eq(title.Text,T('Party stopped'))
            eq(resultTitle.Text,T('PARTY STOPPED'));eq(chooseTitle.Text,T('NEW PARTY'))
        end)
    end
    localize('en-us')
    test('personal boss context uses boss identity when the snapshot name is its human owner',function()
        snapshot=data(8,'Active',{template='Boss',bossType='RoboManus',name='Player Victory',status='Dead'})
        productionMenu();assert(intro.Text:find('Robo-Manus',1,true),'boss owner name must not replace boss identity')
        snapshot={status='Active',view='Menu',enemyRole={template='Boss',status='Dead'}}
        productionMenu();assert(intro.Text:find('Causeway Guardian',1,true),'legacy Guardian snapshots retain their known boss')
    end)
    test('portrait image readiness keeps fallback during pending failure and stale completion',function()
        local pending={}
        Enum.ScaleType={Fit=1};Enum.AssetFetchStatus={Success='success',Failure='failure'}
        Color3={fromRGB=function() return 1 end}
        heroPortraitAssets={['Mr. Green']='123456'}
        frame=function(parent,name)
            local item=node(name);item.children={};item.Parent=parent
            if parent then parent.children[#parent.children+1]=item end
            function item:GetChildren() return self.children end
            function item:IsA(kind) return kind=='GuiObject' end
            return item
        end
        corner=function() end
        Instance={new=function(class)
            local item=node('');item.class=class;item.IsLoaded=false
            function item:IsA(kind) return kind=='GuiObject' or kind==self.class end
            function item:GetPropertyChangedSignal(key)
                assert(key=='IsLoaded')
                return {Connect=function(_,callback) self.changed=callback end}
            end
            return setmetatable(item,{__newindex=function(t,k,v)
                rawset(t,k,v)
                if k=='Parent' and v then v.children[#v.children+1]=t end
            end})
        end}
        task={spawn=function(fn) pending[#pending+1]=fn end}
        local provider={}
        function provider:PreloadAsync(items,callback)
            assert(#items==1 and items[1].class=='ImageLabel','preload the typed ImageLabel')
            if callback then callback(items[1].Image,self.status) end
        end
        game={GetService=function() return provider end}
        for _,outcome in ipairs({'pending','failure','success','removed'}) do
            local art=toadPortrait(nil,1,'Mr. Green')
            local portrait=art.children[#art.children]
            eq(portrait.Image,'rbxassetid://123456')
            for _,child in ipairs(art.children) do if child~=portrait then assert(child.Visible) end end
            if outcome=='removed' then portrait.Parent=nil end
            if outcome~='pending' then
                provider.status=outcome=='failure' and 'failure' or 'success'
                table.remove(pending)()
            else table.remove(pending) end
            -- Native preload can succeed well before the renderer has the image.
            for _,child in ipairs(art.children) do if child~=portrait then assert(child.Visible,'fetch alone must not blank the portrait') end end
            if outcome=='success' or outcome=='removed' then
                portrait.IsLoaded=true;portrait.changed()
                for _,child in ipairs(art.children) do if child~=portrait then eq(child.Visible,outcome=='removed') end end
            end
        end
    end)
    test('boss reaction progress stays separate from cycling raw Life in owner and compact HUD',function()
        for _,locale in ipairs({'en-us','ru-ru','xx-zz'}) do
            localize(locale)
            local enemy={bossType='RoboManus',template='Boss',name='Robo-Manus',status='Alive',connected=true,
                rawLife=0,hearts=0,maxHearts=255,progress=120,maxProgress=240,bossPhase=2}
            snapshot={enemyRole=enemy,heroes={}};mine=nil
            productionResources()
            assert(enemyProgress and enemyProgress.Visible,'owner reaction progress label is missing')
            eq(enemyLife.Text,T('Phase {phase:int} · Life {count:int}/{maximum:int}',{phase=2,count=0,maximum=255}))
            eq(enemyProgress.Text,T('Reaction progress: {count:int}/{maximum:int}',{count=120,maximum=240}))
            assert(enemyProgress.Visible)
            renderMobileSummary({campaignIndex=8,levelName='Machine Ascent'},enemy,true)
            eq(mobileGoalDetail.Text,enemyProgress.Text)
            eq(enemy.hearts,0);eq(enemy.rawLife,0);eq(enemy.progress,120)
            enemy.maxProgress=nil;productionResources();assert(not enemyProgress.Visible)
        end
    end)
    localize('en-us')
    local function panel(klass)
        local p=setmetatable({colors=C,translate=T,selectedBoss=1,sendIntent=function() end,rows={}},klass)
        for _,name in ipairs({'card','heading','note','name','status','detail','primary','secondary','menuCard','hudButton','menuHeading',
            'menuCurrent','menuHelp','menuButton','shell','title','close','current','help','list','create','notice','empty'}) do p[name]=node(name) end
        return p
    end
    local function rect(item,parentW,parentH)
        local w=item.Size.X.Offset+item.Size.X.Scale*(parentW or width)
        local h=item.Size.Y.Offset+item.Size.Y.Scale*(parentH or height)
        local ax=item.AnchorPoint and item.AnchorPoint.X or 0
        local ay=item.AnchorPoint and item.AnchorPoint.Y or 0
        return {x=item.Position.X.Offset+item.Position.X.Scale*(parentW or width)-w*ax,
            y=item.Position.Y.Offset+item.Position.Y.Scale*(parentH or height)-h*ay,w=w,h=h}
    end
    local function overlap(a,b)
        return a.x<b.x+b.w and b.x<a.x+a.w and a.y<b.y+b.h and b.y<a.y+a.h
    end
    local function target(item) assert(item.Size.X.Offset>=44 and item.Size.Y.Offset>=44,item.Name..' hit target below 44px') end
    test('an accepted later boss invitation blocks group switching without naming the Guardian',function()
        local p=panel(GroupPanel)
        p.data={groupId='g',groups={},notice='ROLE_RESERVED',canCreateGroup=true}
        p:_draw();eq(p.notice.Text,'Cancel your accepted boss invitation first.')
        eq(T(noticeMessages.ROLE_RESERVED),'You accepted a boss invitation. Cancel it in the queue first.')
    end)
    for _,menuWidth in ipairs({252,532,940}) do
        for _,state in ipairs({'None','Invited','Accepted'}) do
            test(string.format('%dpx menu %s keeps complete distinct queue controls',menuWidth,state),function()
                bossQueue=panel(BossQueuePanel);bossQueue.card.Visible=true
                bossQueue.queue={state=state,available=true,deadline=120,bossId='GeneralSlaughter'};bossQueue:_draw()
                local h=bossQueue:layout(menuWidth,false)
                target(bossQueue.name);target(bossQueue.primary)
                if state=='Invited' then target(bossQueue.secondary);assert(not overlap(rect(bossQueue.primary),rect(bossQueue.secondary))) end
                assert(not overlap(rect(bossQueue.name),rect(bossQueue.status)))
                assert(not overlap(rect(bossQueue.note),rect(bossQueue.primary)))
                assert(bossQueue.primary.Position.Y.Offset+44<=h)
            end)
        end
    end
    test('queue buttons retain authoritative selection and invitation message contracts',function()
        local sent={}
        local p=panel(BossQueuePanel);p.card.Visible=true;p.selectedBoss=3
        p.sendIntent=function(packet) sent[#sent+1]=packet end
        p.queue={state='None',available=true};p:_activate(true)
        eq(sent[1].kind,'QueueBoss');eq(sent[1].bossId,'RoboManus')
        p.pending=nil;p.queue={state='Invited',deadline=120,offerId='offer-42'};p:_activate(false)
        eq(sent[2].kind,'ReplyBoss');eq(sent[2].offerId,'offer-42');eq(sent[2].accepted,false)
        p.pending=nil;p:_activate(true);eq(sent[3].accepted,true)
        p.pending=nil;p.queue={state='Accepted',deadline=120,offerId='offer-42'};p:_activate(true)
        eq(sent[4].kind,'CancelBossQueue')
        for _,packet in ipairs(sent) do assert(packet.kind~='Start' and not packet.actorId and not packet.hearts and not packet.role) end
    end)
    for _,size in ipairs({{320,568},{320,480},{568,320},{640,360},{1024,768}}) do
        for _,state in ipairs({'None','Invited','Accepted'}) do
            for _,locale in ipairs({'en-us','ru-ru'}) do
                localize(locale)
                test(string.format('%s %dx%d %s actual queue and observer hit bounds',locale,size[1],size[2],state),function()
                    width,height=size[1],size[2];safe.AbsoluteSize={X=width,Y=height}
                    snapshot={status='Active',view='Spectating',heroes={{},{},{}},lobby={},canChooseEnemy=false}
                    bossQueue=panel(BossQueuePanel);bossQueue.card.Visible=true;bossQueue.compact=true
                    bossQueue.queue={state=state,available=true,deadline=120,bossId='RoboManus',groupName='Team 3'}
                    bossQueue:_draw()
                    groupPanel=panel(GroupPanel);groupPanel.hudButton.Visible=true
                    nextHeroButton.Visible=true;personalMenuButton.Visible=true;watchButton.Visible=false;chooseEnemyButton.Visible=false
                    cameraControls.Visible=true;returnToWatch.Visible=false;audioSettings.Parent=scroll
                    productionLayout()
                    target(bossQueue.name);target(bossQueue.primary)
                    if state=='Invited' then target(bossQueue.secondary);assert(not overlap(rect(bossQueue.primary),rect(bossQueue.secondary))) end
                    for _,choice in ipairs(roleButtons) do target(choice.button) end
                    target(personalMenuButton);target(nextHeroButton);target(freeCameraButton)
                    target(groupPanel.hudButton);target(groupPanel.menuButton);target(groupPanel.close);target(groupPanel.create)
                    for _,item in ipairs({audioButton,audioClose,soundToggle,musicToggle,mobileCollapse,mobileGoal,mobileStatus}) do target(item) end
                    for _,item in pairs(directionButtons) do target(item) end
                    for _,item in pairs(cameraButtons) do target(item) end
                    local q,s=rect(bossQueue.card),rect(spectator)
                    if bossQueue.card.Parent==queueHudScroll then
                        assert(queueHudScroll.Visible and queueHudScroll.Size.Y.Offset>=44)
                        assert(queueHudScroll.CanvasSize.Y.Offset>=q.h+s.h+8)
                        assert(not overlap(q,s),'stacked cards overlap')
                        local view=rect(queueHudScroll)
                        assert(not overlap(view,rect(cameraPad)),'scroll viewport clips camera movement')
                        assert(not overlap(view,rect(cameraAxes)),'scroll viewport clips camera axes')
                    else
                        assert(not overlap(q,s),'queue overlaps observer card')
                        assert(not overlap(q,rect(cameraPad)) and not overlap(q,rect(cameraAxes)),'queue overlaps camera controls')
                        assert(not overlap(s,rect(cameraPad)) and not overlap(s,rect(cameraAxes)),'observer overlaps camera controls')
                    end
                    assert(not overlap(rect(nextHeroButton),rect(personalMenuButton)),'camera/view buttons overlap')
                    assert(bossQueue.card.Size.Y.Offset>=bossQueue.primary.Position.Y.Offset+44)
                    assert(not overlap(rect(bossQueue.name),rect(bossQueue.primary)))
                    assert(not overlap(rect(bossQueue.name),rect(bossQueue.detail)))
                    assert(not overlap(rect(bossQueue.status),rect(bossQueue.detail)))
                    assert(not overlap(rect(bossQueue.detail),rect(bossQueue.primary)))
                    assert(not overlap(rect(groupPanel.hudButton),rect(nextHeroButton)),'team and camera buttons overlap')
                    assert(scroll.Size.Y.Offset<0 and scroll.Size.Y.Scale==1,'menu retains a scroll viewport above footer')
                end)
            end
        end
    end
    for _,size in ipairs({{320,480},{568,320},{640,360},{1024,768}}) do
        test(string.format('%dx%d invitation retains a reachable scrolling enemy list',size[1],size[2]),function()
            width,height=size[1],size[2];safe.AbsoluteSize={X=width,Y=height}
            snapshot={status='Active',view='Spectating',heroes={{},{},{}},lobby={},canChooseEnemy=true}
            choosingEnemy=true;cameraControls.Visible=false;nextHeroButton.Visible=false;personalMenuButton.Visible=true;watchButton.Visible=true
            bossQueue=panel(BossQueuePanel);bossQueue.card.Visible=true;bossQueue.compact=true
            bossQueue.queue={state='Invited',deadline=120,bossId='DarkQueen'};bossQueue:_draw()
            groupPanel=panel(GroupPanel);groupPanel.hudButton.Visible=true;productionLayout()
            assert(enemyOffers.Size.Y.Offset>=44,'enemy offers cannot expose a complete touch target')
            target(watchButton);target(personalMenuButton)
            assert(not overlap(rect(watchButton),rect(personalMenuButton)))
            if bossQueue.card.Parent~=queueHudScroll then assert(not overlap(rect(bossQueue.card),rect(spectator))) end
            choosingEnemy=false
        end)
    end
    print(string.format('ReleaseUI: %d PASS, %d FAIL',passed,failed))
    assert(failed==0,'Release UI regressions')
end
