import test from 'node:test';import assert from 'node:assert/strict';
import {normalize,executeTool,runAgent} from './server.mjs';
const base={kind:'chat',message:'现在先练五分钟AWM，再练三分钟变向跟枪',game:{levels:[{id:0,name:'AWM镭射'},{id:14,name:'变向跟枪'},{id:19,name:'三球定位'}]},training:{candidates:[]}};
test('mixed negative and affirmative clauses authorize only a real positive instruction',()=>{
 const c=normalize({...base,message:'不要AWM，带我去三球定位'});
 assert.equal(executeTool('switch_level',{level:19,evidence:'带我去三球定位'},c,{}).status,'pending_client_execution');
 assert.ok(executeTool('switch_level',{level:0,evidence:'不要AWM'},c,{}).error);
 assert.ok(executeTool('switch_level',{level:19,evidence:'马上去三球'},c,{}).error);
});
test('custom route keeps per-stage order, timing and atomic validation',()=>{
 const args={title:'短训练',start:true,evidence:base.message,steps:[{level:0,seconds:300,weapon:'awm'},{level:14,seconds:180}]};
 const c=normalize(base),state={};assert.equal(executeTool('create_training_route',args,c,state).status,'pending_client_execution');
 assert.deepEqual(state.game_action.steps.map(s=>[s.level,s.seconds]),[[0,300],[14,180]]);
 for(const steps of [[{level:999,seconds:300}],[{level:14,seconds:0}],[{level:14.2,seconds:60}],Array(9).fill({level:0,seconds:60})]){
  const untouched={};assert.ok(executeTool('create_training_route',{...args,steps},c,untouched).error);assert.equal(untouched.game_action,undefined);
 }
});
test('a plan request does not authorize starting and one turn cannot apply conflicting operations',()=>{
 const c=normalize({...base,message:'帮我准备一个计划，先别开始'}),args={title:'计划',evidence:'帮我准备一个计划',steps:[{level:14,seconds:180}],start:true};
 assert.ok(executeTool('create_training_route',args,c,{}).error);
 const state={};assert.equal(executeTool('create_training_route',{...args,start:false},c,state).action.kind,'prepare_custom_route');
 assert.ok(executeTool('switch_level',{level:14},c,state).error);
});
test('every chat turn has semantic tools even without an old routing keyword',async()=>{
 let calls=0;
 const c={...base,message:'那个三个球一直刷新的项目，带我过去'};
 const result=await runAgent(c,{model:'test',provider:'ollama',url:'http://127.0.0.1/test'},async(_u,options)=>{
  const body=JSON.parse(options.body);assert.ok(body.tools.some(t=>t.function.name==='create_training_route'));assert.ok(body.tools.some(t=>t.function.name==='read_levels'));
  return {ok:true,json:async()=>({message:++calls===1?{role:'assistant',tool_calls:[{function:{name:'read_levels',arguments:{}}}]}:{role:'assistant',tool_calls:[{function:{name:'switch_level',arguments:{level:19,evidence:c.message}}}]}})};
 });
 assert.equal(result.game_action.level,19);
});

test('semantic production fits a suggested total without another inference', async()=>{
 const {runSemanticAgent}=await import('./server.mjs');let calls=0;
 const result=await runSemanticAgent({...base,message:'现在帮我准备10分钟跟枪计划，先别开始'}, {model:'test',provider:'ollama',url:'http://127.0.0.1/test'},async()=>({ok:true,json:async()=>({message:{content:JSON.stringify({text:'方案',operation:'prepare_custom_route',level:-1,title:'跟枪',evidence:'invented quote',steps:[{level:14,seconds:++calls===1?300:600,weapon:'rifle'}],emotion:'平静',intensity:.5})}})}));
 assert.equal(calls,1);assert.equal(result.game_action.kind,'prepare_custom_route');assert.equal(result.game_action.steps[0].seconds,600);
});
test('full source negation cannot be removed with a misleading quoted substring',()=>{
 const c=normalize({...base,message:'如果带我去三球定位会怎样？'});
 assert.ok(executeTool('switch_level',{level:19,evidence:'带我去三球定位'},c,{}).error);
 const preview=normalize({...base,message:'现在准备一个计划，不要开始'});
 assert.ok(executeTool('create_training_route',{start:true,evidence:preview.message,steps:[{level:14,seconds:300}]},preview,{}).error);
});
test('semantic events never execute a proposed game operation',async()=>{
 const {runSemanticAgent}=await import('./server.mjs');
 const result=await runSemanticAgent({...base,kind:'event',event:'完成训练'}, {model:'test',provider:'ollama',url:'http://127.0.0.1/test'},async()=>({ok:true,json:async()=>({message:{content:JSON.stringify({text:'这轮结束了',operation:'switch_level',level:19,emotion:'激动'})}})}));
 assert.equal(result.game_action,undefined);
});

test('duration fitting preserves explicit stages and all bounds',async()=>{
 const {fitSuggestedDuration}=await import('./intent.mjs');const steps=[{level:13,seconds:300},{level:14,seconds:300},{level:15,seconds:600}];
 const fitted=fitSuggestedDuration('准备10分钟跟枪计划，先看方案',steps);assert.equal(fitted.reduce((s,r)=>s+r.seconds,0),600);assert.deepEqual(fitted.map(s=>s.level),[13,14,15]);assert.ok(fitted.every(s=>s.seconds>=30&&s.seconds<=600));assert.equal(steps[0].seconds,300);
 assert.equal(fitSuggestedDuration('先练五分钟，再练三分钟，最后两分钟',steps),steps);assert.equal(fitSuggestedDuration('每关10分钟的路线',steps),steps);
});
