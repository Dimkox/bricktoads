// Independent official Khronos validation, using an already cached package.
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const validator=require(path.resolve(process.argv[2]));
(async()=>{
  const filenames=['canonical-course-vehicles.glb',...['Speeder','Surfboard','Jet','ClingerVehicle'].map(k=>`${k}/${k}.glb`)];
  const receipts=[];
  for(const filename of filenames){
    const bytes=fs.readFileSync(path.join(__dirname,filename));
    const report=await validator.validateBytes(new Uint8Array(bytes),{uri:filename,maxIssues:1000});
    receipts.push({file:filename,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),...report});
  }
  fs.writeFileSync(path.join(__dirname,'khronos-validation.json'),JSON.stringify({validator:validator.version(),reports:receipts},null,2)+'\n');
  const summary=receipts.map(r=>({file:r.file,errors:r.issues.numErrors,warnings:r.issues.numWarnings,infos:r.issues.numInfos,hints:r.issues.numHints}));
  console.log(JSON.stringify(summary,null,2));
  if(receipts.some(r=>r.issues.numErrors||r.issues.numWarnings))process.exitCode=1;
})().catch(error=>{console.error(error);process.exitCode=1;});
