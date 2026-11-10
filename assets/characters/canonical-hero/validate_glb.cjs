// Optional independent validation using the official Khronos gltf-validator.
// Pass the local directory containing that package as argument1; no network here.
const fs = require('node:fs');
const path = require('node:path');
const validator = require(path.resolve(process.argv[2]));
const file = path.join(__dirname, 'canonical-hero.glb');
validator.validateBytes(new Uint8Array(fs.readFileSync(file)), {
  uri: 'canonical-hero.glb', maxIssues: 1000,
}).then(report => {
  fs.writeFileSync(path.join(__dirname, 'khronos-validation.json'), JSON.stringify(report, null, 2)+'\n');
  process.stdout.write(JSON.stringify({validatorVersion: report.validatorVersion, issues: report.issues}, null, 2)+'\n');
  process.exitCode = report.issues.numErrors === 0 ? 0 : 1;
}).catch(error => { process.stderr.write(String(error)); process.exitCode=1; });
