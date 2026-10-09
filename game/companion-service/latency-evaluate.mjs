import {runSemanticAgent} from './server.mjs';import{readFileSync,writeFileSync}from'node:fs';
const cfg=JSON.parse(readFileSync(new URL('./config.local.json',import.meta.url),'utf8').replace(/^\uFEFF/,''));
cfg.onPlanError=v=>console.log(JSON.stringify({rejected:v}));
const fixture=JSON.parse(readFileSync(new URL('../evidence/agent-upgrade-20260915/game-export-Windows.json',import.meta.url),'utf8'));
const names=['AWM镭射','离心室','门框切角','移动跟枪','喷气突入','航天基地','基础靶场','随机反应','高低差','道具训练','听声辨位','移动测量','训练大厅','平滑跟枪','变向跟枪','中门缝反应','APEX切换','无畏契约移动','CS2清角','三球定位','APEX身法爆头','微小甩枪','下预瞄修正'];
const out=[];for(const message of ['你在干什么呀？','今天练得有点累，陪我聊会儿。','现在先练五分钟AWM，再三分钟变向跟枪，最后两分钟三球。']){
 const start=Date.now();let first=0,calls=0,metrics=[];
 const fetcher=async(u,o)=>{calls++;const res=await fetch(u,o);if(JSON.parse(o.body).stream)return res;const data=await res.json();metrics.push({eval_count:data.eval_count,eval_ms:data.eval_duration/1e6,prompt_count:data.prompt_eval_count,prompt_ms:data.prompt_eval_duration/1e6,load_ms:data.load_duration/1e6});return{ok:res.ok,status:res.status,json:async()=>data}};
 try{const result=await runSemanticAgent({kind:'chat',message,game:{current_level:12,levels:names.map((name,id)=>({id,name}))},mind:{persona:'温柔陪伴'},conversation:[]},{...cfg,onPreview:()=>{first ||= Date.now()-start}},fetcher);out.push({message,ms:Date.now()-start,first_ms:first||null,calls,metrics,result});}catch(e){out.push({message,error:e.message,ms:Date.now()-start})}console.log(JSON.stringify(out.at(-1)));
}writeFileSync(new URL('../evidence/latency-20260915/'+(process.env.LATENCY_ROUND||'baseline')+'.json',import.meta.url),JSON.stringify(out,null,2));
