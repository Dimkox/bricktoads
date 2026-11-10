Prepared native acceptance for stages10 and11 on production build7c03cb19472413e35c22eb6841c6b055ce7a6d07cd930a2d0dcce3c4f5574f9a, seed820297848.

| Stage | Actual endpoint | Time | Final resources |
| --- | --- | ---: | --- |
|10 Race / GeneralSlaughter|Director Won, boss defeated, progress240|143.03s|attempt2, reserves2, rawLife47|
|11 Clinger / Buzzball|Director Won, boss defeated, rawLife0|90.01s|attempt1, reserves3, rawLife47|

Both cases began at the authored safe spawn with rawLife47 and three reserves. Stage10 recorded one CombatUnderflow death, followed by the ordinary paid respawn before its final boss hit. Stage11 recorded no damage or death. The production Director, course simulation, native R6 physics, NPC AI, boss AI, attacks, reactions, shields and lifecycle remained active. Inputs went through ordinary Session Move, Jump and Punch validation at about0.1seconds. The stage10 trace includes96 accepted combat attacks and92 boss hits; stage11 includes58 accepted attacks and55 boss hits.

These are prepared isolated stage tests with a synthetic one-hero server roster. They do not establish registered-client behavior, network/device acceptance, or a continuous campaign playthrough. Each case starts a fresh Session at its stated authored stage; no prior campaign progress is claimed.

The installer clones current production modules with all BaseScripts disabled, injects the frozen QA input modules, then enables only the owned runner. Worlds use offsets Z49152 and53248, Y32. No initial hero pose is prepared. No health, stock, stage, geometry, collision or enemy policy is rewritten. Lighting and Atmosphere state are restored synchronously after construction, before the next yield. Full evidence records all Session/Director events and native samples. Both worlds, their cloned modules and the exported fixture folders were removed afterward.

The first attempt exposed a QA reporter limit: Roblox rejects StringValue contents at200000characters. Its partial reports and input hashes are retained. The shared runner now keeps the full archive in its Script closure, exporting25000-character Read chunks, while Result holds small metadata. Replays successfully exported archives of1036005 and478074characters. This changed reporting only.

Reproduction sources are native_campaign_scene_runner.server.luau and install_native_late_campaign.py in this directory. The installer is an MCP payload generator, not a Studio launcher. From the repository root, use the bundled Python interpreter with the installer script and a stage argument10 or11; execute its generated build/native_late_stageN_install.luau through Studio MCP in main Play Server. It asserts the production build, creates only its unique owned fixture folder, preserves original resources and records real Director completion. Prepared-inputs manifests pin every input-policy and runner hash.

The protected places/BrickToads.rbxlx remains SHA2561974F25E1AF043F3D4A1FE581B5EC9AC818394AC4BC7A747E6FE0CA1F7B5C353.
