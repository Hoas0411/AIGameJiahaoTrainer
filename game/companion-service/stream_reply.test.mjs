import test from 'node:test';import assert from 'node:assert/strict';import {textPreview,readOllamaStream} from './stream_reply.mjs';import {createServer} from './server.mjs';
test('only a confirmed conversational prefix is streamed, never a proposed action',()=>{
 assert.equal(textPreview('{"operation":"none","text":"你好'), '你好');
 assert.equal(textPreview('{"operation":"switch_level","text":"已到三球"}'), '');
 assert.equal(textPreview('{"text":"先说已执行","operation":"none"}'), '');
 assert.equal(textPreview('{"operation":"none","text":"他说\\"你好\\"'), '他说"你好"');
});
test('NDJSON parser tolerates UTF8 and line boundaries split across chunks',async()=>{
 const content='{"operation":"none","text":"你好，小鼠","emotion":"喜欢"}';
 const bytes=new TextEncoder().encode(JSON.stringify({message:{content:content.slice(0,34)}})+'\n'+JSON.stringify({message:{content:content.slice(34)},done:true})+'\n');let at=0;
 const response=new Response(new ReadableStream({pull(c){if(at>=bytes.length)return c.close();c.enqueue(bytes.slice(at,at+5));at+=5;}}));const seen=[];
 const result=await readOllamaStream(response,t=>seen.push(t));assert.equal(result.message.content,content);assert.equal(seen.at(-1),'你好，小鼠');
});
test('truncated streams do not masquerade as a completed answer',async()=>{
 await assert.rejects(readOllamaStream(new Response('{"message":{"content":"partial"}}\n')),/incomplete/);
});
test('progress belongs to one request and disappears on completion',async()=>{
 let release,entered;const ready=new Promise(r=>entered=r);const finish=new Promise(r=>release=r);
 const server=createServer({},async(_c,config)=>{config.onPreview('真实片段');entered();await finish;return{source:'ai',text:'最终答复'}});await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='http://127.0.0.1:'+server.address().port;
 try{const pending=fetch(base+'/companion',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({kind:'chat',message:'你好',request_id:'a'.repeat(32)})});await ready;
 assert.equal((await(await fetch(base+'/progress/'+'a'.repeat(32))).json()).text,'真实片段');assert.equal((await(await fetch(base+'/progress/'+'b'.repeat(32))).json()).text,'');release();await(await pending).json();assert.equal((await(await fetch(base+'/progress/'+'a'.repeat(32))).json()).text,'');
 }finally{release();await new Promise(r=>server.close(r));}
});
