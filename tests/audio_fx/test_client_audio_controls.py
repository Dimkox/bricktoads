"""Execute the production HUD audio-control block and layout without Roblox UI."""
from pathlib import Path
import argparse
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--luau', required=True)
    args = parser.parse_args()
    source = (ROOT / 'src/client/BrickToadsClient.client.luau').read_text(encoding='utf-8')
    assert '-- Audio controls: begin' in source, 'Living players need a compact HUD audio-settings affordance'
    block = source.split('-- Audio controls: begin', 1)[1].split('-- Audio controls: end', 1)[0]
    prelude = '''
local audioOpen=false
local hud,scroll={},{},{}
local C={card=1,ink=2,text=3}
local audioSettings,soundToggle,musicToggle={},{},{}
local mobileExpanded='Goal'
local renderCount,layoutCount=0,0
local syncHook
local function render() renderCount+=1;if syncHook then syncHook(true) end end
local function layout() layoutCount+=1 end
local function T(v)return v end
local function frame(parent,name,color)return {Parent=parent,Name=name} end
local function label(parent,name,text,size,color,bold)return {Parent=parent,Name=name,Text=text} end
local function button(parent,name,text,color,callback)return {Parent=parent,Name=name,Text=text,callback=callback} end
local function corner()end
local UDim2={new=function(...)return {...}end}
local function position(item,x,y,w,h)item.rect={x=x,y=y,w=w,h=h}end
'''
    contracts = '''
syncHook=syncAudioSettings
syncAudioSettings(false)
assert(audioSettings.Parent==scroll and audioSettings.Visible and not audioButton.Visible and not audioPopup.Visible)
syncAudioSettings(true)
assert(audioButton.Visible and not audioPopup.Visible and audioSettings.Parent==audioPopup)
audioButton.callback()
assert(audioOpen and mobileExpanded==nil and audioPopup.Visible and renderCount==1 and layoutCount==1)
for _,screen in ipairs({{320,568,true,104},{844,390,true,56},{1280,720,false,nil}}) do
    layoutAudioSettings(screen[1],screen[2],screen[3],screen[4],12,126,850)
    assert(audioButton.rect.w==44 and audioButton.rect.h==44)
    assert(audioPopup.rect.x>=0 and audioPopup.rect.x+audioPopup.rect.w<=screen[1])
    assert(audioPopup.rect.y>=0 and audioPopup.rect.y+audioPopup.rect.h<=screen[2])
    assert(soundToggle.rect.h==44 and musicToggle.rect.h==44 and audioClose.rect.h==44)
end
audioClose.callback()
assert(not audioOpen and not audioPopup.Visible)
audioButton.callback();syncAudioSettings(false)
assert(not audioOpen and audioSettings.Parent==scroll and not audioPopup.Visible)
print('PASS live audio settings: open/close, menu restoration, 44px touch targets and phone/tablet/desktop bounds')
'''
    with tempfile.TemporaryDirectory(prefix='bricktoads-audio-controls-') as directory:
        runner = Path(directory) / 'controls.luau'
        runner.write_text(prelude + block + contracts, encoding='utf-8')
        return subprocess.run([args.luau, str(runner)], cwd=ROOT).returncode


if __name__ == '__main__':
    raise SystemExit(main())
