return function(Localization,Catalog,GroupPanel,BossQueuePanel)
    local passed=0
    local function test(name,fn) fn();passed+=1;print('PASS '..name) end
    local function eq(a,b) assert(a==b,'expected '..tostring(b)..', got '..tostring(a)) end
    local function parameters(text)
        local names={}
        for name in text:gmatch('{([%w_]+):?[%w_]*}') do names[name]=true end
        return names
    end
    local function fixture(locale)
        local service={RobloxLocaleId=locale}
        local observed={locales={},formatted={}}
        local function create(class)
            eq(class,'LocalizationTable')
            local native={}
            function native:SetEntries(entries)
                self.entries=entries;self.byKey={}
                for _,row in ipairs(entries) do self.byKey[row.Key]=row end
            end
            function native:GetTranslator(id)
                observed.locales[#observed.locales+1]=id
                if observed.failTranslator then error('Translator temporarily unavailable') end
                return {FormatByKey=function(_,key,args)
                    observed.formatted[#observed.formatted+1]={key=key,args=args}
                    if observed.failFormat then error('Translation unavailable') end
                    local row=assert(self.byKey[key],'Unknown key')
                    local text=row.Values[id] or row.Source
                    return (text:gsub('{([%w_]+):?[%w_]*}',function(name)
                        assert(args[name]~=nil,'Missing argument '..name)
                        return tostring(args[name])
                    end))
                end}
            end
            function native:Destroy() self.destroyed=true end
            return native
        end
        return Localization.new(Catalog,service,create),service,observed
    end
    test('all catalog sources are English and translations preserve every named argument',function()
        local seen={}
        assert(#Catalog.entries>=350)
        for _,row in ipairs(Catalog.entries) do
            assert(not seen[row.Key] and row.Key==row.Source and row.Source~='')
            seen[row.Key]=true
            -- Cyrillic UTF-8 starts with D0/D1; source English can retain arrows and heart symbols.
            assert(not row.Source:find('[\208\209]'),'Non-English source: '..row.Source)
            eq(row.Values['en-us'],row.Source)
            assert(type(row.Values.ru)=='string' and row.Values.ru~='')
            local sourceArgs,targetArgs=parameters(row.Source),parameters(row.Values.ru)
            for name in pairs(sourceArgs) do assert(targetArgs[name],'Lost Russian argument '..name) end
            for name in pairs(targetArgs) do assert(sourceArgs[name],'Unknown Russian argument '..name) end
        end
    end)
    test('empty or missing locale uses English and standard native table methods',function()
        local localizer,service,observed=fixture(nil)
        eq(localizer.native.SourceLocaleId,'en-us');eq(localizer.native.Parent,service)
        eq(localizer:text('Start game'),'Start game')
        eq(localizer:text('Enemies: {count:int}',{count=3}),'Enemies: 3')
        eq(observed.locales[1],'en-us');eq(#observed.locales,1)
        eq(observed.formatted[2].key,'Enemies: {count:int}')
        eq(observed.formatted[2].args.count,3)
    end)
    test('selected Russian locale formats counts names and invitation time',function()
        local localizer=fixture('ru-ru')
        eq(localizer:text('Start game'),'Начать игру')
        eq(localizer:text('Enemies: {count:int}',{count=3}),'Врагов: 3')
        eq(localizer:text('Invitation · {seconds:int} s',{seconds=7}),'Приглашение · 7 с')
        eq(localizer:groupName('Team 2','group-2'),'Команда 2')
        eq(localizer:text('Waiting for {host} to start the game.',{host='Victory'}),'Ожидаем: Victory начнёт игру.')
        eq(localizer:text('2  ·  Broken Aqueduct'),'2  ·  Разбитый акведук')
        eq(localizer:text('2  ·  BROKEN AQUEDUCT'),'2  ·  РАЗБИТЫЙ АКВЕДУК')
    end)
    test('locale changes refresh the native translator without translating player argument values',function()
        local localizer,service,observed=fixture('en-us')
        eq(localizer:groupName('Team 4','group-4'),'Team 4')
        service.RobloxLocaleId='ru_RU'
        eq(localizer:groupName('Team 4','group-4'),'Команда 4')
        eq(#observed.locales,2);eq(observed.locales[2],'ru-ru')
        eq(localizer:text('Waiting for {host} to start the game.',{host='Start game'}),'Ожидаем: Start game начнёт игру.')
    end)
    test('missing language or unavailable native translation retains formatted English',function()
        local localizer,_,observed=fixture('xx-zz')
        eq(localizer:text('Enemies: {count:int}',{count=4}),'Enemies: 4')
        observed.failFormat=true
        eq(localizer:text('Invitation · {seconds:int} s',{seconds=9}),'Invitation · 9 s')
        eq(localizer:text('Unlisted title'),'Unlisted title')
        local unavailable,_,failure=fixture('ru-ru');failure.failTranslator=true
        eq(unavailable:text('Start game'),'Start game')
        eq(unavailable:text('Team {index:int}',{index=2}),'Team 2')
        failure.failTranslator=false
        eq(unavailable:text('Start game'),'Начать игру')
    end)
    test('GUI roots use the owned standard table and owner nameplates keep automatic translation off',function()
        local localizer=fixture('ru-ru')
        local gui={};localizer:bind(gui)
        eq(gui.RootLocalizationTable,localizer.native);eq(gui.AutoLocalize,true)
        local world={GetAttribute=function(_,key) return key=='OriginalArt' end}
        local ordinary={Name='WorldLabel',Parent=world,IsA=function(_,kind) return kind=='BillboardGui' end}
        local owner={Name='OwnerNameplate',Parent=world,IsA=ordinary.IsA}
        local workspace={GetDescendants=function() return {ordinary,owner} end,
            DescendantAdded={Connect=function(_,callback) return {Disconnect=function() end} end}}
        localizer:bindWorld(workspace)
        eq(ordinary.RootLocalizationTable,localizer.native);eq(owner.AutoLocalize,false)
    end)
    test('group list dynamic title counts and actions use the selected native translator',function()
        local localizer=fixture('ru-ru')
        local function T(source,args) return localizer:text(source,args) end
        local function groupName(name,id) return localizer:groupName(name,id) end
        local row={}
        local panel=setmetatable({data={groupId='group-1',groupName='Team 1',status='Lobby',canCreateGroup=true,
            groups={{id='group-2',name='Team 2',status='Active',heroes=2,players=3,canJoin=true}}},
            rows={['group-2']=row},menuCurrent={},current={},menuButton={},empty={},create={},notice={},
            colors={},translate=T,groupName=groupName},GroupPanel)
        panel:_draw()
        eq(panel.current.Text,'Сейчас: Команда 1')
        eq(row.Text,'Команда 2 · Идёт игра\nГероев: 2 · игроков: 3\nНаблюдать')
    end)
    test('boss invitation countdown and target team localize as dynamic content',function()
        local localizer=fixture('ru-ru')
        local panel=setmetatable({queue={state='Invited',groupId='group-3',groupName='Team 3'},colors={},
            secondary={},primary={},status={},detail={},compact=true,
            translate=function(source,args) return localizer:text(source,args) end,
            groupName=function(name,id) return localizer:groupName(name,id) end},BossQueuePanel)
        function panel:_remaining() return 7 end
        panel:_draw()
        eq(panel.status.Text,'Приглашение · 7 с')
        eq(panel.detail.Text,'Команда 3 · Примите до конца таймера.')
    end)
    print('Localization: '..passed..' PASS')
end
