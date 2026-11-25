// Export the ImageGen artwork at the requested UHD dimensions.
// The creative redraw is performed by ImageGen; this step only resamples files.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require('C:/Program Files/WindowsApps/OpenAI.CodexPrimaryRuntime.v26-1104-2876-0_26.1104.2876.0_x64__3k8sg7r9htsxt/dependencies/node/node_modules/sharp');
const generated = 'C:/Users/User/.codex/generated_images/01a1c0c4-cc81-7911-b6e8-ca3a3fcc14b3';
const files = [
  ['bosses','exec-b47cb4b3-2cde-4ba5-ace1-ae2086ebf82a.png',6],
  ['enemies-01','exec-2d8bcb14-a824-4084-9f26-713009f18164.png',9],
  ['enemies-02','exec-bbff4dcc-b179-4406-b784-b7c630aed30f.png',9],
  ['enemies-03','exec-708ede3c-9ff0-4b85-9c00-1dfbf3ba8ab1.png',9]
];
async function main() {
  fs.mkdirSync(path.join(__dirname,'native'),{recursive:true});
  const records = [];
  for (const [name,file,subjects] of files) {
    const source = path.join(generated,file);
    const native = path.join(__dirname,'native',name+'-native.png');
    fs.copyFileSync(source,native);
    const metadata = await sharp(source).metadata();
    const target = path.join(__dirname,name+'-uhd.png');
    const info = await sharp(source)
      .resize(3840,2160,{fit:'contain',position:'centre',kernel:'lanczos3',background:{r:242,g:237,b:230,alpha:1}})
      .png({compressionLevel:9})
      .toFile(target);
    if(info.width!==3840 || info.height!==2160) throw new Error('Invalid UHD output');
    records.push({name,subjects,nativeFile:'native/'+name+'-native.png',nativeWidth:metadata.width,nativeHeight:metadata.height,
      outputFile:name+'-uhd.png',width:info.width,height:info.height,bytes:info.size,
      sha256:crypto.createHash('sha256').update(fs.readFileSync(target)).digest('hex')});
  }
  const manifest = {schema:1,tool:'Built-in ImageGen',medium:'2D illustrated remaster reference sheets',
    resolutionNote:'UHD export upscaled from the saved ImageGen native artwork; not native 4K generation.',
    export:{width:3840,height:2160,resampling:'Lanczos3',fit:'contain',preserveAspectRatio:true},
    totalBosses:6,totalEnemyGroups:27,prompts:'prompts.json',sheets:records};
  fs.writeFileSync(path.join(__dirname,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
  console.log(JSON.stringify(manifest,null,2));
}
main().catch(error=>{console.error(error);process.exitCode=1;});
