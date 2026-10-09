import {readFileSync,writeFileSync} from 'node:fs';
import {runAgent} from './server.mjs';
const cfg=JSON.parse(readFileSync(new URL('./config.local.json',import.meta.url),'utf8'));Object.assign(cfg,{model:'qwen3:14b',url:'http://127.0.0.1:11435/api/chat',context:4096,timeoutMs:45000});
const names=['AWM镭射','离心室','门框切角','移动跟枪','喷气突入','航天基地','基础靶场','随机反应','高低差','道具训练','听声辨位','移动测量','训练大厅','平滑跟枪','变向跟枪','中门缝反应','APEX切换','无畏契约移动','CS2清角','三球定位','APEX身法爆头','微小甩枪','下预瞄修正'];
const tests=['我想练那个三个球不断刷新的项目，带我过去吧。','查一下有哪些关卡，先别切换。','我想去那个目标突然变方向、要一直跟住的项目。'];let out=[];
for(const message of tests){let start=Date.now();try{out.push({message,ms:0,result:await runAgent({kind:'chat',message,game:{levels:names.map((name,id)=>({id,name})),current_level:0},memories:[],history:[]},cfg)});}catch(e){out.push({message,error:e.message});}out.at(-1).ms=Date.now()-start;console.log(JSON.stringify(out.at(-1)));}
writeFileSync(new URL('../evidence/companion-actions-20260914/model-tools.json',import.meta.url),JSON.stringify(out,null,2));
