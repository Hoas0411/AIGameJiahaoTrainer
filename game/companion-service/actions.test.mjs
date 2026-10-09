import test from 'node:test';
import assert from 'node:assert/strict';
import {runAgent,normalize,executeTool} from './server.mjs';
const raw={kind:'chat',message:'我想去那个练门缝反应的地方',game:{levels:[{id:15,name:'中门缝反应'}],current_level:0},history:[]};
test('model action is a validated proposal, never a fabricated completed switch',async()=>{
 const result=await runAgent(raw,{model:'test',provider:'ollama',url:'http://127.0.0.1:11434/api/chat'},async()=>({ok:true,json:async()=>({message:{role:'assistant',content:'',tool_calls:[{function:{name:'switch_level',arguments:{level:15}}}]}})}));
 assert.deepEqual(result.game_action,{kind:'switch_level',level:15});assert.equal(result.text,'正在切换。');assert.deepEqual(result.tools,['switch_level']);
});
test('unknown or noninteger level and negated/hypothetical action rejected',()=>{
 for(const level of [-1,23,99,15.3,'15'])assert.ok(executeTool('switch_level',{level},normalize(raw),{}).error);
 for(const message of ['不要带我去中门','如果换到中门会怎样','如何切换到中门','我不想去中门'])assert.ok(executeTool('switch_level',{level:15},normalize({...raw,message}),{}).error);
 assert.ok(executeTool('switch_level',{level:15},normalize({...raw,kind:'event'}),{}).error);
});
test('catalog never exposes paths or arbitrary commands',()=>{
 const c=normalize({...raw,game:{levels:[{id:15,name:'中门',path:'C:/private'},{id:999,name:'bad'}]}});
 assert.deepEqual(c.game.levels,[{id:15,name:'中门'}]);assert.equal(executeTool('run_shell',{},c,{}).error,'tool not allowed');
});
import http from 'node:http';
import {createServer} from './server.mjs';
test('closing client cancels pending inference and releases service',async()=>{
 let enter;const entered=new Promise(r=>enter=r);let calls=0;
 const s=createServer({},async(_input,config)=>{if(calls++>0)return {source:'ai',text:'ok'};enter();return await new Promise((_resolve,reject)=>config.signal.addEventListener('abort',()=>reject(Error('cancelled')),{once:true}));});
 await new Promise(r=>s.listen(0,'127.0.0.1',r));
 try{const url=`http://127.0.0.1:${s.address().port}/companion`;const controller=new AbortController();const pending=fetch(url,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(raw),signal:controller.signal}).catch(()=>{});await entered;controller.abort();await pending;await new Promise(r=>setTimeout(r,40));const response=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(raw)});assert.equal(response.status,200);}finally{s.closeAllConnections();await new Promise(r=>s.close(r));}
});

test('confirmation only authorizes the single proposed catalog destination',()=>{
 const base={...raw,message:'是的',conversation:[{role:'assistant',source:'ai',content:'你是指中门缝反应吗？'}]};
 assert.equal(executeTool('switch_level',{level:15},normalize(base),{}).status,'pending_client_execution');
 assert.ok(executeTool('switch_level',{level:15},normalize({...base,conversation:[]}),{}).error);
 assert.ok(executeTool('switch_level',{level:15},normalize({...base,message:'不是'}),{}).error);
 assert.ok(executeTool('switch_level',{level:15},normalize({...base,conversation:[{role:'assistant',content:'你在中门缝反应练了几轮？'}]}),{}).error);
});
test('absent statistics are a disclosed data receipt, never an invented model evaluation',async()=>{
 const r=await runAgent({...raw,message:'评价我的枪法',history:[]},{provider:'ollama',model:'test',url:'http://127.0.0.1:11435/api/chat'},()=>{throw Error('must not invent evaluation');});
 assert.equal(r.source,'local');assert.deepEqual(r.routed_tools,['read_training']);assert.match(r.text,/没有已结算/);
});
test('factual rejection requests a fresh model answer without publishing the rejected claim',async()=>{
 const outputs=[{text:'你今天来晚了',action:'idle'},{unsupported:true,reason:'没有来访时间'},{text:'想聊什么？',action:'idle'},{unsupported:false,reason:''}];
 const r=await runAgent({kind:'chat',message:'你好',memories:[]},{provider:'ollama',model:'test',url:'http://127.0.0.1:11435/api/chat',verifyReplies:true},async()=>({ok:true,json:async()=>({message:{content:JSON.stringify(outputs.shift())}})}));
 assert.equal(r.text,'想聊什么？');assert.equal(r.source,'ai');assert.equal(outputs.length,0);
});
