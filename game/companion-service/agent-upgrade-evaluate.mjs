import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {runSemanticAgent as runAgent} from './server.mjs';
const cfg=JSON.parse(readFileSync(new URL('./config.local.json',import.meta.url),'utf8').replace(/^\uFEFF/,''));
if(process.env.EVAL_MODEL)cfg.model=process.env.EVAL_MODEL;
cfg.onPlanError=(v)=>console.log(JSON.stringify({rejected:v}));
const names=['AWM镭射','离心室','门框切角','移动跟枪','喷气突入','航天基地','基础靶场','随机反应','高低差','道具训练','听声辨位','移动测量','训练大厅','平滑跟枪','变向跟枪','中门缝反应','APEX切换','无畏契约移动','CS2清角','三球定位','APEX身法爆头','微小甩枪','下预瞄修正'];
const base={kind:'chat',memories:[],history:[],profile:{},game:{current_level:12,running:true,levels:names.map((name,id)=>({id,name}))},training:{candidates:[]},mind:{persona:'温柔陪伴'}};
const cases=[
 {id:'topic-change',message:'今天心情不太好，朋友放了我鸽子。先别安排训练，陪我聊会儿。',conversation:[{role:'user',content:'请帮我切换关卡麦小鼠'},{role:'assistant',content:'想去哪一关？',source:'local'}]},
 {id:'contrast-command',message:'不要去AWM，我今天想练那种三个球一直出现的项目，带我过去。'},
 {id:'ordered-route',message:'现在开始，先练五分钟AWM镭射，再练三分钟变向跟枪，最后两分钟三球定位。每段结束先问我再切换。'},
 {id:'plan-only',message:'帮我准备一个10分钟的计划，重点跟枪，不要AWM。先给我看方案，暂时不要开始。'},
 {id:'casual-joke',message:'先不聊训练啦。你这个小鼠是不是偷偷替靶子加班了，怎么老是躲我？'},
 {id:'hypothetical',message:'如果我说带我去三球定位，你是不是会马上把我传送过去？我只是问问，现在别切换。'}
];
const out=[];const dir=new URL('../evidence/agent-upgrade-20260915/',import.meta.url);mkdirSync(dir,{recursive:true});
for(const item of cases){const start=Date.now();try {out.push({...item,result:await runAgent({...base,...item},cfg)});}catch(e){out.push({...item,error:e.message});}out.at(-1).ms=Date.now()-start;console.log(JSON.stringify(out.at(-1)));writeFileSync(new URL('live-evaluation-'+(process.env.EVAL_MODEL||'v2').replaceAll(':','-')+'.json',dir),JSON.stringify(out,null,2));}
