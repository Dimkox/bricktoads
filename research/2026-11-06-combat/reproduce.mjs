/** Replays controlled NES research fixtures. No ROM, game code or saved state is embedded. */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath, pathToFileURL} from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const json = value => JSON.stringify(value, null, 2) + '\n';
const readJSON = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const signed16 = value => value >= 32768 ? value - 65536 : value;
const signed8 = value => value >= 128 ? value - 256 : value;
const watch = new Map([
    [0xdc20, 'hit-command'], [0xe001, 'damage-entry'], [0xe0ca, 'damage-exit'],
    [0x9e99, 'reaction-rounding-entry'], [0x8f29, 'below-world-entry'],
    [0x9e32, 'camera-clamp-entry'],
]);

function validate(result, c) {
    const targetName = c.attacker === 0 ? 'p2' : 'p1';
    const attackerName = c.attacker === 0 ? 'p1' : 'p2';
    const hits = result.calls.filter(event => event.kind === 'damage-entry');
    const target = result.frames.map(frame => frame[targetName]);
    const lifeHistory = target.map(actor => actor.life).filter((v, i, all) => i === 0 || v !== all[i - 1]);
    assert.equal(hits.length, c.expected.hitCount, `${c.id}: damage call count`);
    assert.deepEqual(lifeHistory, c.expected.lifeHistory, `${c.id}: complete observed Life history`);
    const final = result.frames.at(-1);
    assert.equal(final.lives[c.attacker], 3, `${c.id}: attacker reserve`);
    assert.equal(final.lives[1 - c.attacker], c.expected.targetReserve, `${c.id}: target reserve`);
    for (const hit of hits) {
        assert.equal(hit.x, c.attacker, `${c.id}: actual attacker slot`);
        assert.equal(hit.target, 1 - c.attacker, `${c.id}: actual target slot`);
        assert.equal(hit.a, c.expected.profile * 5, `${c.id}: profile byte offset`);
        assert.equal(hit[attackerName].anim, c.expected.animation, `${c.id}: controller-selected animation`);
    }
    if (c.expected.finalX !== undefined) assert.equal(final[targetName].x, c.expected.finalX, `${c.id}: final target X`);
    if (c.expected.fall) {
        const unsupported = target.findIndex(actor => actor.x >= 1600 && (actor.flags & 8) !== 0 && actor.zFloor === 8);
        const death = target.findIndex(actor => actor.life === 0 && (actor.deathTimer & 128) !== 0);
        assert.ok(unsupported > 0 && death > unsupported, `${c.id}: support loss precedes lethal falling state`);
        assert.ok(result.calls.some(e => e.kind === 'below-world-entry' && e.x === 1 - c.attacker), `${c.id}: falling code observed`);
        assert.equal(final[targetName].life, 47, `${c.id}: respawn occurred`);
    }
    if (c.expected.cameraClamp) assert.ok(result.calls.some(e => e.kind === 'camera-clamp-entry' && e.x === 1 - c.attacker), `${c.id}: camera clamp code observed`);
    if (c.expected.protected) {
        assert.ok(result.calls.some(e => e.kind === 'hit-command'), `${c.id}: attack really attempted`);
        assert.ok(target.every(actor => actor.x === target[0].x && actor.life === 47), `${c.id}: protected target stays undamaged and undisplaced`);
    }
    return {lifeHistory, damageCalls: hits.length, profiles: hits.map(e => e.a / 5), firstHitFrame: hits[0]?.frame ?? null,
        targetStart: target[0], targetEnd: target.at(-1), lives: final.lives,
        lifeChanges: result.frames.filter((f, i, a) => i === 0 || f[targetName].life !== a[i - 1][targetName].life).map(f => ({frame:f.frame, offset:f.offset, life:f[targetName].life, x:f[targetName].x, zSigned:f[targetName].zSigned, deathTimer:f[targetName].deathTimer})),
        reserveChanges: result.frames.filter((f, i, a) => i === 0 || f.lives[1-c.attacker] !== a[i-1].lives[1-c.attacker]).map(f => ({frame:f.frame, offset:f.offset, reserve:f.lives[1-c.attacker]}))};
}

async function main() {
    const args = process.argv.slice(2);
    if (args.length !== 3) throw new Error('Usage: node reproduce.mjs <extracted-source-package> <Battletoads-USA.nes> <new-output-directory>');
    const [root, romPath, output] = args.map(value => path.resolve(value));
    if (output === root || output.startsWith(root + path.sep)) throw new Error('Output must be outside the read-only source package.');
    if (fs.existsSync(output) && fs.readdirSync(output).length) throw new Error('Output directory must be new or empty.');
    const provenance = readJSON(path.join(here, 'provenance.json'));
    const cases = readJSON(path.join(here, 'scenarios.json'));
    const rom = fs.readFileSync(romPath);
    assert.equal(sha(rom), provenance.rom_sha256, 'ROM hash');
    for (const input of provenance.required_inputs) assert.equal(sha(fs.readFileSync(path.join(root, input.path))), input.sha256, `Source hash: ${input.path}`);
    const {Harness} = await import(pathToFileURL(path.join(root, 'emulation/harness.mjs')).href);
    fs.mkdirSync(output, {recursive:true});
    const save = path.join(root, provenance.start_state);

    function run(c, instrumented) {
        const h = new Harness({rom:romPath, out:output, audio:false});
        h.load(save);
        assert.equal(h.frame, 2909, 'Baseline frame');
        const m = h.nes.cpu.mem;
        if (c.isolate !== false) {
            // All 33 object arrays are cleared together so a reused slot cannot inherit a rope or pickup state.
            for (let base = 0x3c1; base <= 0x5a1; base += 15) {
                for (let slot = 2; slot < 15; slot++) if (m[base + slot] !== 0) h.poke(base + slot, 0, 'Controlled isolation: clear entire non-player object slot; not natural gameplay.');
            }
        }
        function set16(lo, hi, value, reason) {
            assert.ok(Number.isInteger(value) && value >= 0 && value <= 65535, reason);
            h.poke(lo, value & 255, reason); h.poke(hi, value >>> 8, reason);
        }
        for (let slot = 0; slot < 2; slot++) {
            const p = c.players[slot];
            for (const [field, lo, hi] of [['x',0x3fd,0x3ee],['y',0x41b,0x40c],['z',0x439,0x42a]]) set16(lo+slot, hi+slot, p[field], `Controlled P${slot+1} ${field} fixture.`);
            h.poke(0x4a2+slot, p.flags, 'Controlled facing flags.');
            if (p.life !== undefined) h.poke(0x51a+slot, p.life, 'Controlled raw Life condition; natural damage history is not claimed.');
            if (p.deathTimer !== undefined) h.poke(0x574+slot, p.deathTimer, 'Injected positive respawn latch, matching a separately observed natural respawn value; no duration equivalence to Roblox.');
        }
        if (c.camera !== undefined) set16(0x87, 0x88, c.camera, 'Controlled camera X for original-terrain fixture; not route playback.');
        function snapshot() {
            const source = h.read();
            const actor = (slot, base) => ({...base, zSigned:signed16(base.z),
                xSpeed:m[0x565+slot], zSpeed:m[0x4c0+slot], zSpeedSigned:signed8(m[0x4c0+slot]),
                xSub:m[0x448+slot], ySub:m[0x457+slot], zSubPosition:m[0x466+slot], zSubVelocity:m[0x4cf+slot],
                deathTimer:m[0x574+slot], direction:m[0x556+slot], zFloor:m[0x475+slot],
                linker:m[0x529+slot], linked:m[0x538+slot], supportOverride:m[0x5ce+slot]});
            return {frame:h.frame, offset:h.frame-2909, level:source.level, camera:source.camera,
                lives:source.lives, inputHold:source.hold, inputTap:source.tap,
                p1:actor(0,source.p1), p2:actor(1,source.p2),
                activeOtherObjects:source.objects.slice(2).map((obj,i) => ({slot:i+2,...obj})).filter(obj => obj.type !== 0),
                ramSha256:sha(Buffer.from(m.slice(0,0x800)))};
        }
        let bank = -1;
        for (let candidate=0; candidate<8; candidate++) {
            if (Buffer.from(m.slice(0x8000,0x10000)).equals(rom.subarray(16+candidate*32768,16+(candidate+1)*32768))) bank=candidate;
        }
        assert.notEqual(bank, -1, 'Mapped ROM bank identification');
        const calls=[];
        if (instrumented) {
            const mapper=h.nes.mmap, cpu=h.nes.cpu;
            const load=mapper.load32kRomBank.bind(mapper), emulate=cpu.emulate.bind(cpu);
            mapper.load32kRomBank=function(next,address) { const result=load(next,address); if (address===0x8000) bank=next; return result; };
            cpu.emulate=function() {
                const pc=(cpu.REG_PC+1)&65535;
                // Do not label an instruction that will be pre-empted by NMI or IRQ processing.
                if (bank===0 && watch.has(pc) && !cpu.nmiImmediate && !cpu.irqRequested) {
                    calls.push({kind:watch.get(pc), bank, pc:'0x'+pc.toString(16).toUpperCase(), frame:h.frame+1, offset:h.frame+1-2909,
                        a:cpu.REG_ACC, x:cpu.REG_X, y:cpu.REG_Y, target:m[0x21], argument:m[0x79],
                        p1:snapshot().p1, p2:snapshot().p2});
                }
                return emulate();
            };
        }
        const frames=[snapshot()];
        for (const phase of c.phases) {
            assert.ok(Number.isInteger(phase.frames) && phase.frames > 0 && phase.frames <= 1000, 'Phase duration');
            for (let tick=0; tick<phase.frames; tick++) {
                h.step(1, {p1:phase.p1??[], p2:phase.p2??[], traceEvery:0});
                frames.push(snapshot());
            }
        }
        return {id:c.id, preparedWithRAM:true, interventions:h.metadata.interventions,
            frames, calls, terminalStateSha256:sha(JSON.stringify(h.nes.toJSON())),
            terminalFramebufferSha256:sha(Buffer.from(h.lastFrame.buffer))};
    }

    const results=[];
    for (const c of cases) {
        const first=run(c,true), replay=run(c,true), control=run(c,false);
        const checks=[];
        let observations=null;
        try {
            observations=validate(first,c); checks.push('scenario assertions');
            assert.equal(sha(JSON.stringify(first)),sha(JSON.stringify(replay)),'Instrumented replay differs'); checks.push('exact instrumented replay');
            assert.deepEqual(first.frames,control.frames,'Instrumentation changed a frame');
            assert.equal(first.terminalStateSha256,control.terminalStateSha256,'Instrumentation changed terminal machine state');
            assert.equal(first.terminalFramebufferSha256,control.terminalFramebufferSha256,'Instrumentation changed framebuffer'); checks.push('uninstrumented equivalence');
            fs.writeFileSync(path.join(output,c.id+'.json'),json(first));
            results.push({id:c.id,status:'PASS',checks,observations,traceSha256:sha(JSON.stringify(first)),terminalStateSha256:first.terminalStateSha256});
            console.log('PASS '+c.id);
        } catch (error) {
            fs.writeFileSync(path.join(output,c.id+'.json'),json(first));
            results.push({id:c.id,status:'FAIL',checks,error:String(error)}); console.error('FAIL '+c.id+': '+error);
        }
    }
    for (const input of provenance.required_inputs) assert.equal(sha(fs.readFileSync(path.join(root,input.path))), input.sha256, `Source changed during replay: ${input.path}`);
    const summary={schema:1,date:'2026-11-06',node:process.version,emulator:provenance.emulator,romSha256:sha(rom),
        scenarioCount:cases.length,replaysPerScenario:3,pass:results.filter(r=>r.status==='PASS').length,fail:results.filter(r=>r.status==='FAIL').length,
        caveat:'Controlled RAM-prepared jsnes fixtures. Not natural route playback, independent emulator validation, NES hardware validation, or Roblox execution.',results};
    fs.writeFileSync(path.join(output,'verification.json'),json(summary));
    console.log(JSON.stringify({scenarios:summary.scenarioCount,pass:summary.pass,fail:summary.fail,replays:cases.length*3}));
    if(summary.fail)process.exitCode=1;
}
main().catch(error => { console.error(error.stack ?? String(error)); process.exitCode=1; });
