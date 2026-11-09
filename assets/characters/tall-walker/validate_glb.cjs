const fs=require('node:fs');
const path=require('node:path');
const validator=require(path.resolve(process.argv[2]));
validator.validateBytes(new Uint8Array(fs.readFileSync(path.join(__dirname,'tall-walker.glb'))),{
  uri:'tall-walker.glb',maxIssues:1000,
}).then(report=>{
  fs.writeFileSync(path.join(__dirname,'khronos-validation.json'),JSON.stringify(report,null,2)+'\n');
  process.stdout.write(JSON.stringify({validatorVersion:report.validatorVersion,issues:report.issues},null,2)+'\n');
  process.exitCode=report.issues.numErrors?1:0;
}).catch(error=>{process.stderr.write(String(error));process.exitCode=1;});
