-- Minimal Roblox GUI value adapter: the actual production geometry is executed.
function node(name)
    return {Name=name,Visible=true,Position={X={Offset=0,Scale=0},Y={Offset=0,Scale=0}},
        Size={X={Offset=0,Scale=0},Y={Offset=0,Scale=0}},AnchorPoint={X=0,Y=0},
        AbsoluteSize={X=640,Y=360},Text='',TextSize=14}
end
UDim2={new=function(xs,x,ys,y) return {X={Scale=xs or 0,Offset=x or 0},Y={Scale=ys or 0,Offset=y or 0}} end}
function UDim2.fromOffset(x,y) return UDim2.new(0,x,0,y) end
function UDim2.fromScale(x,y) return UDim2.new(x,0,y,0) end
UDim={new=function(s,o) return {Scale=s,Offset=o} end}
Vector2={new=function(x,y) return {X=x,Y=y} end}
Enum={TextYAlignment={Top=1,Center=2},TextXAlignment={Left=1,Right=2},TextTruncate={AtEnd=1,None=2}}
C={lime=1,red=2,yellow=3,text=4,muted=5,ink=6,card=7}
UserInputService={TouchEnabled=true}
workspace={GetServerTimeNow=function() return 100 end}
CombatFeedback={aliveHeroes=function() return 3 end}
roleButtons={{button=node('Hero')},{button=node('Enemy')},{button=node('Watch')}}
heroCards={};partyRows={};heroRows={};enemyHearts={};mobileHearts={}
directionButtons={};cameraButtons={}
for _,name in ipairs({'Forward','Left','Right','Backward'}) do directionButtons[name]=node(name) end
for _,name in ipairs({'Up','Down','Left','Right'}) do cameraButtons[name]=node(name) end
function position(item,x,y,w,h) item.Position=UDim2.fromOffset(x,y);item.Size=UDim2.fromOffset(w,h) end
function enemyChoiceAllowed() return snapshot and snapshot.canChooseEnemy end
function playable() return false end
function syncAudioSettings() end
soundMuted=false;musicMuted=false;actionPending=false
width=640;height=360;choosingEnemy=false;feedbackUntil=0
