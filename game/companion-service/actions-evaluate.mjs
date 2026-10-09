import {readFileSync,writeFileSync} from 'node:fs';
import {runAgent} from './server.mjs';
const config=JSON.parse(readFileSync(new URL('./config.local.json',import.meta.url),'utf8'));
config.model=process.argv[2]??config.model;config.url=process.argv[3]??config.url;config.timeoutMs=90000;if(config.model==="qwen3:14b")config.context=4096;if(process.argv[4]==="review")config.verifyReplies=true;if(process.argv[4]==="think"){config.thinking=true;config.maxPredict=1536;}
const cases=JSON.parse(readFileSync(new URL('../evidence/companion-actions-20260914/baseline.json',import.meta.url),'utf8')).map(({id,message})=>({id,message}));
cases.push({id:'holdout_frustration',message:'同事又把锅甩给我了。我现在真的不想听什么换位思考。'}, {id:'holdout_joy',message:'我终于敢在会上反驳他了，手都在抖，但还是说完了。'}, {id:'holdout_boundary',message:'今晚我想自己待着，明天再来找你。'}, {id:'holdout_recall',message:'我为什么不喜欢被催？',memories:['玩家不喜欢被催，因为小时候做什么都被要求快一点。']}, {id:'holdout_joke',message:'你这只鼠是不是只会夸我？我想听句真话。'}, {id:'holdout_followup',message:'不是枪法，是今天心情差。',conversation:[{role:'user',content:'今天不太想练。'},{role:'assistant',content:'是练累了，还是心里有别的事？',source:'ai'}]});
const out=[];
for(const item of cases){const start=Date.now();try{const result=await runAgent({kind:'chat',message:item.message,profile:{partner:'训练搭档',style:'温柔具体'},mind:{persona:'温柔陪伴'},memories:item.memories??[],history:[],conversation:item.conversation??[]},config);out.push({...item,result,ms:Date.now()-start});}catch(e){out.push({...item,error:e.message,ms:Date.now()-start});}writeFileSync(new URL('../evidence/companion-actions-20260914/'+config.model.replaceAll(':','-')+'-evaluation.json',import.meta.url),JSON.stringify({model:config.model,results:out},null,2));console.log(item.id,out.at(-1).ms,out.at(-1).error??out.at(-1).result.text);}




