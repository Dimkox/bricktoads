from pathlib import Path
R=Path(__file__).resolve().parent
t=(R/'fixture-preemptive.lua').read_text()
t=t.replace(' local w=FakeWorld.new()',""" local bossStarted=false
 local Modes=require('../../src/server/gameplay/CampaignModes')
 local retryView=setmetatable({definition=def,course=def.course,actors={[1]={finished=true}},session={order={1}}},{__index=Modes})
 local retry=Modes.respawnPosition(retryView,1)
 assert(retry.x==f.x-15 and retry.y==f.y+f.h/2+3 and retry.z==f.z,'Actual finished single-slot CampaignModes respawn contract')
 local w=FakeWorld.new()""")
t=t.replace('function w:findSafe()return table.clone(start)end','function w:findSafe()return table.clone(bossStarted and retry or start)end')
t=t.replace(' local b=Boss.new(s,w,cfg,def)',' local b=Boss.new(s,w,cfg,def);bossStarted=true')
(R/'fixture-preemptive-retry.lua').write_text(t)
t=(R/'probe-preemptive.luau').read_text().replace("require('./fixture-preemptive')","require('./fixture-preemptive-retry')").replace('WHOLE_PREEMPTIVE','WHOLE_PREEMPTIVE_RETRY')
(R/'probe-preemptive-retry.luau').write_text(t)
baseline=(R/'probe-baseline.luau').read_text().replace("require('./fixture')","require('./fixture-preemptive-retry')").replace('WHOLE_BASELINE','WHOLE_BASELINE_RETRY')
(R/'probe-baseline-retry.luau').write_text(baseline)
print('Corrected post-constructor retry to production CampaignModes finished slot1 position; pre-test resource calibration remains separate')
