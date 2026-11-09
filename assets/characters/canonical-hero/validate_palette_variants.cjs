// Independent official Khronos validation; argument1 is a local validator package.
const fs=require('node:fs');
const path=require('node:path');
const validator=require(path.resolve(process.argv[2]));
(async()=>{
  let failures=0;
  for(const player of [1,2]){
    const name=`canonical-hero-player${player}`;
    const report=await validator.validateBytes(new Uint8Array(fs.readFileSync(path.join(__dirname,name+'.glb'))),{uri:name+'.glb',maxIssues:1000});
    fs.writeFileSync(path.join(__dirname,name+'.khronos.json'),JSON.stringify(report,null,2)+'\n');
    process.stdout.write(JSON.stringify({file:name+'.glb',version:report.validatorVersion,issues:report.issues})+'\n');
    failures+=report.issues.numErrors;
  }
  process.exitCode=failures?1:0;
})().catch(error=>{process.stderr.write(String(error));process.exitCode=1;});
