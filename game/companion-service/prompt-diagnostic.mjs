import {runAgent} from './server.mjs';
const raw={kind:'chat',message:'你还记得我为什么不喜欢别人催我吗？',profile:{partner:'训练搭档',style:'温柔具体'},mind:{persona:'温柔陪伴'},memories:[],conversation:[],history:[]};
for(const mode of ['plain','schema']){
 const out=await runAgent(raw,{model:'qwen3:14b',provider:'ollama',url:'http://127.0.0.1:11435/api/chat',context:4096},async(url,opts)=>{const p=JSON.parse(opts.body);if(mode==='plain')delete p.format;console.log(mode,'system length',p.messages[0].content.length);const r=await fetch(url,{...opts,body:JSON.stringify(p)});const d=await r.json();console.log('RAW',JSON.stringify(d.message),d.prompt_eval_count);return {ok:r.ok,status:r.status,json:async()=>d};});console.log(mode,JSON.stringify(out));}
