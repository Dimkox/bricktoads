const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const validator = require(path.resolve(process.argv[2]));
const file = 'boss-walker.glb';
const bytes = fs.readFileSync(path.join(__dirname, file));
validator.validateBytes(new Uint8Array(bytes), { uri: file, maxIssues: 1000 }).then(report => {
  report.validatedArtifact = { file, bytes: bytes.length, sha256: crypto.createHash('sha256').update(bytes).digest('hex') };
  fs.writeFileSync(path.join(__dirname, 'boss-walker-khronos.json'), JSON.stringify(report, null, 2) + '\n');
  process.stdout.write(JSON.stringify(report.issues) + '\n');
  process.exitCode = report.issues.numErrors ? 1 : 0;
}).catch(error => { process.stderr.write(String(error)); process.exitCode = 1; });
