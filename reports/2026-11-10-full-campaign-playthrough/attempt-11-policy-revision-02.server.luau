local f=script.Parent
local Http=game:GetService('HttpService')
local proof={scope='QA input-selection revision during an ordinary campaign; production code and game state unchanged',
 runId='d59c909e-aaef-4678-945d-ff1838791ab5',productionSourceSha256=f:GetAttribute('ProductionSourceSha256'),
 oldCombatSha256=f:GetAttribute('OldCombatSha256'),newCombatSha256=f:GetAttribute('NewCombatSha256'),samples={}}
local ok,err=xpcall(function()
 local qa=assert(_G.BrickToadsFullCampaignQA)
 assert(qa.running and qa.current.runId==proof.runId and qa.current.index==1)
 assert(qa.build==proof.productionSourceSha256 and qa.policyLoads==1 and not qa.inputRevision02)
 local read=game.ServerStorage.BrickToadsFullCampaignRead
 proof.before=Http:JSONDecode(read:Invoke())
 local prior=require(game.ServerScriptService.BrickToadsQA.campaign_combat_pilot)
 local nextPolicy=require(f.CorrectedCombatInputPilot)
 assert(type(nextPolicy.plan)=='function')
 prior.plan=nextPolicy.plan
 qa.policyLoads=2;qa.inputRevision02=true
 proof.appliedAt=workspace:GetServerTimeNow();proof.applied=true
 f:SetAttribute('Status','Applied');f.Result.Value=Http:JSONEncode(proof)
 for _=1,60 do
  task.wait(.1)
  local view=Http:JSONDecode(read:Invoke())
  proof.samples[#proof.samples+1]={at=workspace:GetServerTimeNow(),current=view.current,cohort=view.cohort,policyLoads=view.policyLoads}
 end
 proof.after=Http:JSONDecode(read:Invoke());proof.complete=true
end,debug.traceback)
if not ok then proof.error=tostring(err) end
f:SetAttribute('Status',ok and 'Complete' or 'Failed')
f.Result.Value=Http:JSONEncode(proof)
