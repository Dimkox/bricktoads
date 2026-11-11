const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const validator = require(path.resolve(process.argv[2]));

Promise.all(['brawler-player2', 'brawler-brown'].map(async name => {
  const file = name + '.glb';
  const artifact = fs.readFileSync(path.join(__dirname, file));
  const report = await validator.validateBytes(new Uint8Array(artifact), {uri: file, maxIssues: 1000});
  report.validatedArtifact = {file, bytes: artifact.length, sha256: crypto.createHash('sha256').update(artifact).digest('hex')};
  fs.writeFileSync(path.join(__dirname, name + '-khronos.json'), JSON.stringify(report, null, 2) + '\n');
  process.stdout.write(JSON.stringify({file, validatorVersion: report.validatorVersion, issues: report.issues}) + '\n');
  return report.issues.numErrors;
})).then(errors => {process.exitCode = errors.some(Boolean) ? 1 : 0;}).catch(error => {
  process.stderr.write(String(error));process.exitCode = 1;
});
