"""Prepare an MCP-only installer for isolated native campaign scenes10..13."""
from pathlib import Path
import hashlib
import json
import sys

ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / 'src/server/gameplay/CampaignDefinition.lua').is_file())
stage = int(sys.argv[1])
assert stage in (10, 11, 12, 13)
seed = int(sys.argv[2]) if len(sys.argv) > 2 else 820297848
folder = f"Native{'Early' if stage < 12 else 'Late'}CampaignScene{stage}"
offset_z = 49152 + (stage-10)*4096 if stage < 12 else 65536 + (stage-12)*4096
report = ROOT / ("reports/2026-11-10-native-campaign-10-11" if stage < 12 else "reports/2026-11-10-native-late-campaign-12-13")
report.mkdir(parents=True, exist_ok=True)
sources = {
    "LatePilot": (ROOT / "tools/qa/campaign_late_course_pilot.lua").read_text(encoding="utf-8"),
    "EarlyPilot": (ROOT / "tools/qa/campaign_early_course_pilot.lua").read_text(encoding="utf-8"),
    "CombatPilot": (ROOT / "tools/qa/campaign_combat_pilot.lua").read_text(encoding="utf-8"),
}
nav = (ROOT / "tools/studio_level_route_driver.luau").read_text(encoding="utf-8")
marker = "if not game then return Nav end"
assert marker in nav
sources["Nav"] = nav.split(marker, 1)[0] + "\nreturn Nav\n"
runner_path = Path(__file__).with_name('native_campaign_scene_runner.server.luau')
if not runner_path.is_file():
    runner_path = ROOT / "build/native_campaign_scene_runner.server.luau"
sources["Runner"] = runner_path.read_text(encoding="utf-8")

def quote(value):
    for n in range(10):
        eq = "=" * n
        if "]" + eq + "]" not in value:
            return "[" + eq + "[" + value + "]" + eq + "]"
    raise ValueError("Luau long-string delimiter unavailable")

hashes = {name: hashlib.sha256(source.encode()).hexdigest() for name, source in sources.items()}
code = [
    "assert(game:GetService('RunService'):IsStudio() and game:GetService('RunService'):IsRunning() and game:GetService('RunService'):IsServer(),'Require current main Play Server')",
    "assert(game.PlaceId==117412694427208,'Wrong place')",
    "local project=assert(game.ServerScriptService:FindFirstChild('BrickToads'))",
    "assert(require(project.BuildInfo).sourceSha256=='7c03cb19472413e35c22eb6841c6b055ce7a6d07cd930a2d0dcce3c4f5574f9a','Unexpected production build')",
    f"assert(not game.ServerScriptService:FindFirstChild('{folder}'),'Owned scene already exists')",
    f"local owner=Instance.new('Folder');owner.Name='{folder}';owner:SetAttribute('Owner','native_campaign_scene')",
    f"owner:SetAttribute('StageIndex',{stage});owner:SetAttribute('Seed',{seed});owner:SetAttribute('HeroSlot',1)",
    f"owner:SetAttribute('OffsetZ',{offset_z});owner:SetAttribute('OffsetY',32)",
    "owner:SetAttribute('MaxSimTime',240);owner:SetAttribute('InputCadence',.1)",
    "owner:SetAttribute('ProductionSourceSha256','7c03cb19472413e35c22eb6841c6b055ce7a6d07cd930a2d0dcce3c4f5574f9a')",
    f"owner:SetAttribute('PolicySha256',{quote(json.dumps(hashes, sort_keys=True))})",
    "local clone=project:Clone();clone.Name='OwnedModules';for _,v in ipairs(clone:GetDescendants()) do if v:IsA('BaseScript') then v.Disabled=true end end;clone.Parent=owner",
]
for name, source in sources.items():
    if name == "Runner":
        continue
    code += [f"local m=Instance.new('ModuleScript');m.Name='{name}';m.Source={quote(source)};m.Parent=owner",
             f"owner:SetAttribute('{name}Sha256','{hashes[name]}')"]
code += ["local result=Instance.new('StringValue');result.Name='Result';result.Parent=owner",
         "local read=Instance.new('BindableFunction');read.Name='Read';read.Parent=owner",
         "owner.Parent=game.ServerScriptService",
         f"local runner=Instance.new('Script');runner.Name='Runner';runner.Disabled=true;runner.Source={quote(sources['Runner'])};runner.Parent=owner",
         f"owner:SetAttribute('RunnerSha256','{hashes['Runner']}')",
         "runner.Disabled=false",
         "return game.HttpService:JSONEncode({folder=owner:GetFullName(),stage=owner:GetAttribute('StageIndex'),owner=owner:GetAttribute('Owner'),status=owner:GetAttribute('Status')})"]
target = ROOT / f"build/native_late_stage{stage}_install.luau"
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text("\n".join(code) + "\n", encoding="utf-8")
receipt = {"stage": stage, "seed": seed, "folder": folder, "offsetZ": offset_z,
           "productionBuild": "7c03cb19472413e35c22eb6841c6b055ce7a6d07cd930a2d0dcce3c4f5574f9a",
           "sourceSha256": hashes, "scope": "Prepared isolated normal-input native scene; no full campaign claim"}
(report / f"stage{stage}-prepared-inputs.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"installer": str(target), "length": target.stat().st_size, "sources": hashes}))
