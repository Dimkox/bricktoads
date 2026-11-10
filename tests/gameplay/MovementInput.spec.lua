return function(MovementInput,RobloxInputBindings)
    local passed=0
    local function test(name,fn) fn();passed+=1;print('PASS '..name) end
    local function near(a,b) assert(math.abs(a-b)<.00001,tostring(a)..' ~= '..tostring(b)) end
    test('one held native Bool direction walks and repeated press notifications cannot create a run',function()
        local input=MovementInput.new()
        assert(input:press('Right',0));assert(not input:press('Right',.1))
        local v=input:vector();assert(v.x==1 and v.z==0 and not v.run)
        input:release('Right');v=input:vector();assert(v.x==0 and v.z==0 and not v.run)
    end)
    test('press release press within a quarter second runs only while that direction stays held',function()
        local input=MovementInput.new()
        input:press('Right',0);input:release('Right');input:press('Right',.2)
        assert(input:vector().run,'A real second press after release must latch running')
        input:release('Right');assert(not input:vector().run)
        input:press('Forward',.22);assert(not input:vector().run)
    end)
    test('double tap uses an inclusive press-to-press deadline rather than release-to-press time',function()
        local exact=MovementInput.new();exact:press('Left',0);exact:release('Left');exact:press('Left',.25)
        assert(exact:vector().run)
        local late=MovementInput.new();late:press('Left',0);late:release('Left');late:press('Left',.251)
        assert(not late:vector().run)
        local held=MovementInput.new();held:press('Left',0);held:release('Left');held:press('Left',1)
        assert(not held:vector().run)
    end)
    test('independent simultaneous direction actions normalize diagonals and release only their own axis',function()
        local input=MovementInput.new();input:press('Forward',0);input:press('Right',.1)
        local v=input:vector();near(v.x,1/math.sqrt(2));near(v.z,-1/math.sqrt(2))
        input:release('Forward');v=input:vector();assert(v.x==1 and v.z==0)
        input:release('Right');v=input:vector();assert(v.x==0 and v.z==0)
    end)
    test('opposite directions cancel movement and cannot hide a running latch that resumes later',function()
        local input=MovementInput.new();input:press('Right',0);input:release('Right');input:press('Right',.2)
        input:press('Left',.21);local v=input:vector();assert(v.x==0 and v.z==0 and not v.run)
        input:release('Left');assert(not input:vector().run)
    end)
    test('a second independent direction keeps diagonal run until the actual running direction is released',function()
        local input=MovementInput.new();input:press('Forward',0);input:release('Forward');input:press('Forward',.2)
        input:press('Right',.21);assert(input:vector().run)
        input:release('Forward');assert(not input:vector().run and input:vector().x==1)
    end)
    test('opposition on the other axis does not cancel an independently held running direction',function()
        local input=MovementInput.new();input:press('Forward',0);input:release('Forward');input:press('Forward',.2)
        input:press('Right',.21);input:press('Left',.22)
        local v=input:vector();assert(v.x==0 and v.z==-1 and v.run)
    end)
    test('camera-relative projection follows rotated and vertical cameras without changing run intent',function()
        local input=MovementInput.new();input:press('Forward',0)
        local v=input:vector({x=1,z=0});near(v.x,1);near(v.z,0)
        v=input:vector({x=0,z=0});near(v.x,0);near(v.z,-1)
    end)
    test('context reset clears held directions and tap history across focus body and view changes',function()
        local input=MovementInput.new();input:press('Right',0);input:release('Right');input:press('Right',.2)
        input:reset();assert(input:vector().x==0 and not input:vector().run)
        input:press('Right',.21);assert(not input:vector().run)
    end)
    test('interruption can retain native held directions as walking without manufacturing another tap',function()
        local input=MovementInput.new();input:press('Forward',0);input:release('Forward');input:press('Forward',.2)
        input:reset({Forward=true,Right=true})
        local v=input:vector();assert(v.x>0 and v.z<0 and not v.run)
        assert(not input:press('Forward',.21));assert(not input:vector().run)
        input:release('Forward');input:press('Forward',.22);assert(not input:vector().run)
    end)
    test('different owners never share pressed directions or double tap history',function()
        local a,b=MovementInput.new(),MovementInput.new();a:press('Right',0);a:release('Right');a:press('Right',.2)
        assert(a:vector().run and b:vector().x==0 and not b:vector().run)
        b:press('Right',.21);assert(not b:vector().run)
    end)
    local function fakeEngine()
        local instances={}
        local function signal()
            local listeners={}
            return {Connect=function(_,fn)
                local row={fn=fn,connected=true};table.insert(listeners,row)
                return {Disconnect=function() row.connected=false end}
            end,emit=function()
                for _,row in ipairs(listeners) do if row.connected then row.fn() end end
            end}
        end
        local enum={InputActionType={Bool='Bool'},InputBindingType={Automatic='Automatic'},
            KeyCode={W='W',A='A',S='S',D='D',Space='Space',F='F',R='R'}}
        local factory={new=function(class)
            local instance={ClassName=class,Pressed=signal(),Released=signal(),state=false}
            function instance:GetState() return self.state end
            function instance:Destroy() self.destroyed=true end
            table.insert(instances,instance);return instance
        end}
        return {Instance=factory,Enum=enum},instances
    end
    test('native binding context is disabled Bool Automatic with independent keyboard and UIButton bindings',function()
        local engine,instances=fakeEngine()
        local buttons={Forward={},Backward={},Left={},Right={},Jump={},Attack={},Mega={}}
        local bindings=RobloxInputBindings.new({},buttons,{},engine)
        assert(not bindings.context.Enabled and bindings.context.Priority==2000 and bindings.context.Sink)
        local actionCount,bindingCount=0,0
        for _,instance in ipairs(instances) do
            if instance.ClassName=='InputAction' then actionCount+=1;assert(instance.Type=='Bool') end
            if instance.ClassName=='InputBinding' then bindingCount+=1;assert(instance.Type=='Automatic') end
        end
        assert(actionCount==7 and bindingCount==14)
        assert(bindings.actions.Forward.Parent==bindings.context)
        bindings:destroy();assert(bindings.context.destroyed)
    end)
    test('native press release callbacks preserve independent directions and simultaneous jump attack',function()
        local engine=fakeEngine();local input=MovementInput.new();local actions={};local now=0
        local bindings=RobloxInputBindings.new({}, {}, {
            press=function(direction) input:press(direction,now) end,
            release=function(direction) input:release(direction) end,
            action=function(action) table.insert(actions,action) end,
        },engine)
        bindings.actions.Forward.Pressed.emit();assert(input:vector().z==0)
        bindings:setEnabled(true)
        bindings.actions.Forward.Pressed.emit();bindings.actions.Right.Pressed.emit()
        bindings.actions.Jump.Pressed.emit();bindings.actions.Attack.Pressed.emit()
        assert(input:vector().x>0 and input:vector().z<0 and actions[1]=='Jump' and actions[2]=='Attack')
        bindings.actions.Forward.Released.emit();assert(input:vector().x==1 and input:vector().z==0)
        bindings.actions.Right.state=true
        assert(bindings:heldDirections().Right)
        bindings:setEnabled(false);bindings.actions.Mega.Pressed.emit();assert(#actions==2)
        bindings:destroy();bindings.actions.Right.Released.emit();assert(input:vector().x==1)
    end)
    print('MovementInput: '..passed..' PASS')
end
