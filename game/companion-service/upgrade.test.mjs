import test from 'node:test';
import assert from 'node:assert/strict';
import {normalize,executeTool,runAgent,health} from './server.mjs';
import http from 'node:http';

const raw={kind:'chat',message:'帮我安排15分钟跟枪路线',mind:{persona:'沉静教练',preferences:{service:{value:'先陪伴，暂不建议训练',source:'先陪我'}}},training:{candidates:[{id:'tracking',title:'跟枪进阶',steps:[{level:13,title:'平滑跟枪',seconds:300,weapon:'rifle',goal:'减少过冲'}]}]}};
test('training tool prepares only supported candidates and refuses invalid/event mutations',()=>{
  const c=normalize(raw),state={};
  assert.equal(executeTool('plan_training',{focus:'tracking',minutes:15},c,state).status,'prepared_for_player_selection');
  assert.equal(state.route_focus,'tracking');
  for(const args of [{focus:'delete_save',minutes:15},{focus:'laser',minutes:15},{focus:'tracking',minutes:NaN},{focus:'tracking',minutes:0},{focus:'tracking',minutes:1.5}]) assert.ok(executeTool('plan_training',args,c,{}).error);
  assert.ok(executeTool('plan_training',{focus:'tracking',minutes:15},{...c,kind:'event'},{}).error);
});
test('real agent loop returns route execution receipt and bounded emotion with personality context',async()=>{
  let round=0;
  const result=await runAgent(raw,{model:'fixture',provider:'ollama',url:'http://127.0.0.1/test'},async(_url,options)=>{
    const body=JSON.parse(options.body);
    assert.match(body.messages[0].content,/沉稳/);
    assert.match(body.messages[0].content,/先陪伴/);
    if(round++===0) return {ok:true,json:async()=>({message:{role:'assistant',tool_calls:[{function:{name:'plan_training',arguments:{focus:'tracking',minutes:15}}}]}})};
    assert.equal(JSON.parse(body.messages.at(-1).content).status,'prepared_for_player_selection');
    return {ok:true,json:async()=>({message:{content:JSON.stringify({text:'路线已准备好，去路线页选择开始。',emotion:'激动',intensity:999,action:'cheer'})}})};
  });
  assert.equal(result.route_focus,'tracking');assert.equal(result.intensity,1);assert.equal(result.emotion,'激动');
  assert.deepEqual(result.tools,['plan_training']);
});
test('malicious mind fields do not become executable state',()=>{
  const c=normalize({...raw,mind:{persona:'__proto__',preferences:{command:{value:'rm'},style:{value:'安静'}}}});
  assert.equal(c.mind.persona,'温柔陪伴');assert.equal(c.mind.preferences.command,undefined);
});
test('semantic preference learning requires exact evidence and a bounded value',()=>{
  const c=normalize({...raw,message:'说话温柔一点，不要催我'}),state={};
  assert.ok(executeTool('learn_preference',{key:'style',value:'温柔具体',evidence:'说话温柔一点'},c,state).preference);
  assert.ok(executeTool('learn_preference',{key:'style',value:'生气',evidence:'说话温柔一点'},c,state).error);
  assert.ok(executeTool('learn_preference',{key:'style',value:'温柔具体',evidence:'我喜欢你温柔'},c,state).error);
});
test('explicit route request executes tool even when a small model only promises it',async()=>{
  const result=await runAgent(raw,{model:'fixture',provider:'ollama',url:'http://127.0.0.1/test'},async()=>({ok:true,json:async()=>({message:{content:'{"text":"我安排好了"}'}})}));
  assert.equal(result.route_focus,'tracking');assert.deepEqual(result.routed_tools,['plan_training']);assert.match(result.text,/选择开始/);
});
test('health does not confuse a manifest with usable model weights',async()=>{
  const server=http.createServer((req,res)=>{res.setHeader('Content-Type','application/json');if(req.url==='/api/show'){res.statusCode=404;res.end('{"error":"model not found"}');}else res.end('{"models":[{"name":"incomplete"}]}');});
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  try {const result=await health({provider:'ollama',model:'incomplete',url:`http://127.0.0.1:${server.address().port}/api/chat`});assert.equal(result.ready,false);assert.match(result.error,/不完整/);}finally{await new Promise(r=>server.close(r));}
});
