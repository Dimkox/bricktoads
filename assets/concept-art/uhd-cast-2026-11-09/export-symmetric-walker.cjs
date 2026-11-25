const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require('C:/Program Files/WindowsApps/OpenAI.CodexPrimaryRuntime.v26-1104-2876-0_26.1104.2876.0_x64__3k8sg7r9htsxt/dependencies/node/node_modules/sharp');
const source = 'C:/Users/User/.codex/generated_images/01a1c0c4-cc81-7911-b6e8-ca3a3fcc14b3/exec-0a45aa12-685b-4dc9-8227-1cf0dee0483e.png';
async function main() {
  fs.mkdirSync(path.join(__dirname,'native'),{recursive:true});
  const native = path.join(__dirname,'native','boss-walker-symmetric-native.png');
  fs.copyFileSync(source,native);
  const meta = await sharp(source).metadata();
  const target = path.join(__dirname,'boss-walker-symmetric-uhd.png');
  const info = await sharp(source).resize(2160,3840,{fit:'contain',position:'centre',kernel:'lanczos3',background:{r:242,g:237,b:230,alpha:1}}).png({compressionLevel:9}).toFile(target);
  if(info.width!==2160 || info.height!==3840) throw new Error('Wrong export dimensions');
  const manifest = {tool:'Built-in ImageGen',character:'Boss Walker',presentation:'Symmetric full-body front elevation',authoredReconstruction:true,
    sourceComponents:'Original crimson mechanical intro leg and camera-relative cannon',nativeFile:'native/boss-walker-symmetric-native.png',nativeWidth:meta.width,nativeHeight:meta.height,
    uhdFile:'boss-walker-symmetric-uhd.png',width:info.width,height:info.height,bytes:info.size,export:'UHD export upscaled using Lanczos3, aspect ratio preserved',
    promptFile:'boss-walker-symmetric-prompt.json',sha256:crypto.createHash('sha256').update(fs.readFileSync(target)).digest('hex')};
  fs.writeFileSync(path.join(__dirname,'boss-walker-symmetric-manifest.json'),JSON.stringify(manifest,null,2)+'\n');
  console.log(JSON.stringify(manifest));
}
main().catch(e=>{console.error(e);process.exitCode=1;});

