import {runSemanticAgent}from'./server.mjs';import{readFileSync}from'node:fs';
const cfg=JSON.parse(readFileSync(new URL('./config.local.json',import.meta.url),'utf8').replace(/^\uFEFF/,''));cfg.onPlanError=v=>console.log(JSON.stringify(v));cfg.onPreview=()=>{};
const f=JSON.parse(readFileSync(new URL('../evidence/latency-20260915/game-Windows.json',import.meta.url),'utf8'));
const names=['AWM镭射','离心室','门框切角','移动跟枪','喷气突入','航天基地','基础靶场','随机反应','高低差','道具训练','听声辨位','移动测量','训练大厅','平滑跟枪','变向跟枪','中门缝反应','APEX切换','无畏契约移动','CS2清角','三球定位','APEX身法爆头','微小甩枪','下预瞄修正'];
const index=f.transcript.findIndex(x=>x.input.startsWith('帮我准备10分钟'));
const conversation=f.transcript.slice(0,index).flatMap(x=>[{role:'user',content:x.input},{...x.reply}]).slice(-12);
try{console.log(JSON.stringify(await runSemanticAgent({kind:'chat',message:f.transcript[index].input,game:{current_level:12,levels:names.map((name,id)=>({id,name}))},mind:{persona:'温柔陪伴'},conversation},cfg)))}catch(e){console.log(e.message)}
