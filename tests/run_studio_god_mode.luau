local Policy=require('../src/server/gameplay/StudioGodMode')
local function storage(initial)
    local s={value=initial,writes=0}
    function s:GetAttribute(name) assert(name=='BrickToadsGodMode');return self.value end
    function s:SetAttribute(name,value) assert(name=='BrickToadsGodMode');self.value=value;self.writes+=1;if self.changed then self.changed() end end
    function s:GetAttributeChangedSignal(name)
        assert(name=='BrickToadsGodMode')
        return {Connect=function(_,callback) self.changed=callback;return {} end}
    end
    return s
end
local public={Development={allowInfiniteLives=true,infiniteLives=true}};local saved=storage(true)
local denied=Policy.attach(public,false,saved)
assert(public.Development.allowInfiniteLives==false and public.Development.infiniteLives==false and saved.writes==0)
denied:bind({setInfiniteLives=function() error('published toggle must never bind') end})
local config={};local s=storage(nil);local p=Policy.attach(config,true,s)
assert(s.value==true and config.Development.allowInfiniteLives and config.Development.infiniteLives)
local calls={};p:bind({setInfiniteLives=function(_,enabled) calls[#calls+1]=enabled;return 'OK' end})
s:SetAttribute('BrickToadsGodMode',false);assert(calls[#calls]==false and config.Development.infiniteLives==false)
s:SetAttribute('BrickToadsGodMode',true);assert(calls[#calls]==true and config.Development.infiniteLives==true)
s:SetAttribute('BrickToadsGodMode','true');assert(calls[#calls]==false and config.Development.infiniteLives==false)
local disabled={};Policy.attach(disabled,true,storage(false));assert(disabled.Development.infiniteLives==false)
print('StudioGodMode: 6 contracts PASS')
