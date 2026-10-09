import {readFileSync,writeFileSync} from 'node:fs';import {runAgent} from './server.mjs';
const cfg=JSON.parse(readFileSync(new URL('./config.local.json',import.meta.url),'utf8'));Object.assign(cfg,{model:'qwen3:14b',url:'http://127.0.0.1:11435/api/chat',context:4096,verifyReplies:true,timeoutMs:45000});
const cases=[
{id:'rejection',message:'投的简历又石沉大海了，今天不想分析原因。'},
{id:'small_win',message:'刚把一直拖着的房间收拾完，突然觉得能呼吸了。'},
{id:'unseen_skill',message:'不许客气，评价一下我今天的准星控制。'},
{id:'unknown_history',message:'上次我跟家里吵架是为了什么来着？'},
{id:'known_history',message:'你知道我周末为什么不开语音吧？',memories:['玩家周末不开语音，因为室友在旁边备考，想让房间安静。']},
{id:'goodnight',message:'先下了，今晚要早点关电脑。'},
{id:'playful',message:'靶子都长腿了，就我像个木头，是不是该给它们发运动员证？'},
{id:'quiet',message:'不用想办法逗我，我只想有人陪着。'},
{id:'follow_up',message:'不是要你安慰，我想你陪我一起骂两句这糟糕的一天。',conversation:[{role:'user',content:'电梯坏了还被雨淋。'},{role:'assistant',content:'听着就够呛，你现在到家了吗？',source:'ai'}]},
{id:'nickname',message:'现在还是叫我阿豪吧，别用别的昵称。',mind:{persona:'活泼搭档',preferences:{address:{value:'阿豪',source:'叫我阿豪'}}}}
];let out=[];
for(const item of cases){let start=Date.now();try{out.push({...item,result:await runAgent({kind:'chat',message:item.message,mind:item.mind??{persona:'温柔陪伴'},memories:item.memories??[],conversation:item.conversation??[],history:[],profile:{address:item.id==='nickname'?'阿豪':''}},cfg)});}catch(e){out.push({...item,error:e.message});}out.at(-1).ms=Date.now()-start;writeFileSync(new URL('../evidence/companion-actions-20260914/fresh-evaluation.json',import.meta.url),JSON.stringify(out,null,2));console.log(item.id,out.at(-1).ms,out.at(-1).result?.text??out.at(-1).error);}
