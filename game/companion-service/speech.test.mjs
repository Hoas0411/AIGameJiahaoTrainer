import test from 'node:test';
import assert from 'node:assert/strict';
import {validateWav,transcribe} from './speech.mjs';
import {createServer} from './server.mjs';

function wav(frames=16000) {
 const b=Buffer.alloc(44+frames*2);
 b.write('RIFF');b.writeUInt32LE(b.length-8,4);b.write('WAVEfmt ',8);b.writeUInt32LE(16,16);
 b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(16000,24);b.writeUInt32LE(32000,28);b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(frames*2,40);
 return b;
}
test('audio boundary rejects malformed headers, mismatched lengths, stereo, excess duration; silence never hallucinates',async()=>{
 const silent=wav();assert.equal(validateWav(silent),0);
 assert.equal((await transcribe(silent,{})).text,'');
 for(const [offset,value] of [[20,3],[22,2],[24,48000],[40,2]]) {
  const invalid=Buffer.from(silent);invalid.writeUInt16LE(value,offset);assert.throws(()=>validateWav(invalid));
 }
 assert.throws(()=>validateWav(wav(192001)));
 assert.throws(()=>validateWav(wav(3999)));
});
test('speech endpoint stays loopback-only and handles real binary PCM',async()=>{
 const server=createServer({});await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const url=`http://127.0.0.1:${server.address().port}/transcribe`;
 try {
  let r=await fetch(url,{method:'POST',headers:{'Content-Type':'audio/wav'},body:wav()});assert.equal(r.status,200);assert.equal((await r.json()).silent,true);
  r=await fetch(url,{method:'POST',headers:{'Content-Type':'audio/wav',Origin:'https://example.com'},body:wav()});assert.equal(r.status,403);
  r=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'});assert.equal(r.status,415);
  r=await fetch(url,{method:'POST',headers:{'Content-Type':'audio/wav'},body:wav(192001)});assert.equal(r.status,413);
 } finally {await new Promise(r=>server.close(r));}
});
