// Independent official Khronos validation from the existing cached package.
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const validator=require(path.resolve(process.argv[2]));
(async()=>{
  const pack=JSON.parse(fs.readFileSync(path.join(__dirname,'canonical-course-props-pack.json'),'utf8'));
  const filenames=[pack.glb,...Object.keys(pack.templates).map(k=>`${k}/${k}.glb`)];
  const reports=[];
  for(const filename of filenames){
    const bytes=fs.readFileSync(path.join(__dirname,filename));
    const report=await validator.validateBytes(new Uint8Array(bytes),{uri:filename,maxIssues:1000});
    reports.push({file:filename,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),...report});
  }
  fs.writeFileSync(path.join(__dirname,'khronos-validation.json'),JSON.stringify({validator:validator.version(),reports},null,2)+'\n');
  console.log(JSON.stringify(reports.map(r=>({file:r.file,errors:r.issues.numErrors,warnings:r.issues.numWarnings,infos:r.issues.numInfos,hints:r.issues.numHints})),null,2));
  if(reports.some(r=>r.issues.numErrors||r.issues.numWarnings))process.exitCode=1;
})().catch(error=>{console.error(error);process.exitCode=1;});
