const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const validator=require(path.resolve(process.argv[2]));
const artifact=fs.readFileSync(path.join(__dirname,'green-brawler.glb'));
validator.validateBytes(new Uint8Array(artifact),{
  uri:'green-brawler.glb',maxIssues:1000,
}).then(report=>{
  report.validatedArtifact={file:'green-brawler.glb',bytes:artifact.length,sha256:crypto.createHash('sha256').update(artifact).digest('hex')};
  fs.writeFileSync(path.join(__dirname,'green-brawler-khronos.json'),JSON.stringify(report,null,2)+'\n');
  process.stdout.write(JSON.stringify({validatorVersion:report.validatorVersion,issues:report.issues},null,2)+'\n');
  process.exitCode=report.issues.numErrors?1:0;
}).catch(error=>{process.stderr.write(String(error));process.exitCode=1;});
