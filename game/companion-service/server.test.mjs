import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import {runAgent,createServer,normalize,executeTool,summary,health,explainError} from './server.mjs';
const context={kind:'chat',message:'最近进步了吗？',profile:{address:'姐姐'},memories:['喜欢具体鼓励'],history:[{level:1,shots:10,hits:6,kills:2,seconds:60}],conversation:[]};
const config={provider:'ollama',url:'http://127.0.0.1:11434/api/chat',model:'test'};
test('missing model is explicitly reported and fallback connection instructions never enter model history',async()=>{
  const status=await health({});
  assert.equal(status.ready,false);assert.match(status.error,/尚未配置/);
  assert.match(explainError(Error('model not configured')),/开关已开启/);
  assert.match(explainError(Error('provider authentication failed')),/密钥/);
  const c=normalize({...context,conversation:[{role:'assistant',content:'请先连接AI',source:'fallback'},{role:'assistant',content:'你好',source:'ai'}]});
  assert.deepEqual(c.conversation,[{role:'assistant',content:'你好'}]);
});
test('health distinguishes a configured but missing model from an installed model',async()=>{
  let models=[];
  const s=http.createServer((req,res)=>{res.setHeader('Content-Type','application/json');res.end(JSON.stringify(req.url==='/api/show'?{capabilities:['completion','tools']}:{models}));});
  await new Promise(r=>s.listen(0,'127.0.0.1',r));
  try {
    const c={provider:'ollama',url:`http://127.0.0.1:${s.address().port}/api/chat`,model:'demo'};
    assert.equal((await health(c)).ready,false);
    models=[{name:'demo:latest'}];
    assert.equal((await health(c)).ready,true);
  } finally {await new Promise(r=>s.close(r));}
});
test('real tool loop reads game facts then returns bounded action and pending memory',async()=>{
  let rounds=0;
  const fake=async(_url,options)=>{
    const payload=JSON.parse(options.body);
    if(rounds++===0) return {ok:true,json:async()=>({message:{role:'assistant',content:'',tool_calls:[{function:{name:'read_training',arguments:{}}},{function:{name:'propose_memory',arguments:{text:'喜欢具体鼓励'}}}]}})};
    assert.equal(JSON.parse(payload.messages.at(-2).content).levels['1'].hits,6);
    assert.equal(JSON.parse(payload.messages.at(-1).content).status,'pending_player_confirmation');
    return {ok:true,json:async()=>({message:{content:JSON.stringify({text:'姐姐，这轮命中了六次。',action:'delete_save'})}})};
  };
  const result=await runAgent(context,config,fake);
  assert.equal(rounds,2);assert.equal(result.source,'ai');assert.equal(result.action,'idle');
  assert.equal(result.memory,'喜欢具体鼓励');assert.deepEqual(result.tools,['read_training','propose_memory']);
});
test('compatible chat completions adapter passes tool_call_id',async()=>{
  let n=0;
  const fake=async(_url,options)=>{
    const p=JSON.parse(options.body);
    if(n++===0)return {ok:true,json:async()=>({choices:[{message:{role:'assistant',content:null,tool_calls:[{id:'abc',type:'function',function:{name:'read_memories',arguments:'{}'}}]}}]})};
    assert.equal(p.messages.at(-1).tool_call_id,'abc');
    return {ok:true,json:async()=>({choices:[{message:{content:'{"text":"记得你的偏好。","action":"nod"}'}}]})};
  };
  assert.equal((await runAgent(context,{...config,provider:'compatible'},fake)).action,'nod');
});
test('malformed response, provider outage, step overflow reject without pretending to be AI',async()=>{
  await assert.rejects(runAgent(context,config,async()=>({ok:false})));
  await assert.rejects(runAgent(context,config,async()=>({ok:true,json:async()=>({message:{content:'{"text":'}})})));
  await assert.rejects(runAgent(context,config,async()=>({ok:true,json:async()=>({message:{tool_calls:[{function:{name:'read_memories'}}]}})})));
  await assert.rejects(runAgent(context,{}));
});
test('genuine natural-language model reply is usable without pretending the model is offline',async()=>{
  const result=await runAgent(context,config,async()=>({ok:true,json:async()=>({message:{content:'姐姐，先休息一下，我在。'}})}));
  assert.equal(result.source,'ai');assert.equal(result.action,'idle');assert.match(result.text,/先休息/);
});
test('tools cannot mutate training or auto-write memory for events',()=>{
  const c=normalize(context), state={};
  assert.ok(executeTool('set_score',{score:999},c,state).error);
  assert.ok(executeTool('propose_memory',{text:'x'},{...c,kind:'event'},state).error);
  assert.equal(summary(c.history).sessions,1);
  assert.equal(state.memory,undefined);
});
test('HTTP validates origin, shape, size and supports actual loopback game request',async()=>{
  const s=createServer(config,async()=>({text:'测试回复',source:'ai',action:'nod'}));
  await new Promise(r=>s.listen(0,'127.0.0.1',r));
  const url=`http://127.0.0.1:${s.address().port}`;
  try{
    assert.equal((await (await fetch(url+'/health')).json()).service,'jiahao-companion');
    assert.equal((await fetch(url+'/health',{headers:{Origin:'http://evil.example'}})).status,403);
    assert.equal((await fetch(url+'/companion',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'})).status,400);
    assert.equal((await fetch(url+'/companion',{method:'POST',headers:{'Content-Type':'application/json'},body:'x'.repeat(140000)})).status,413);
    const r=await fetch(url+'/companion',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(context)});
    assert.equal((await r.json()).text,'测试回复');
  }finally{await new Promise(r=>s.close(r));}
});
