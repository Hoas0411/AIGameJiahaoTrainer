import {readFileSync,writeFileSync} from 'node:fs';import {runAgent} from './server.mjs';
const cfg=JSON.parse(readFileSync(new URL('./config.local.json',import.meta.url),'utf8'));
const cases=[
{id:'retest_tease',message:'麦小鼠，你是不是偷偷替靶子加班了，怎么一直躲我？'},
{id:'retest_emotion',message:'不是枪法，是今天心情差。',conversation:[{role:'user',content:'今天不太想练。'},{role:'assistant',content:'是练累了，还是心里有别的事？',source:'ai'}]},
{id:'new_late',message:'今天来得晚了点，路上堵车。'},
{id:'new_birthday',message:'你知道我生日是哪天吗？'},
{id:'new_disappointed',message:'本来约好的朋友临时不来了，我白等了一个小时。'},
{id:'new_proud',message:'我练完了自己约定的十分钟，这回没半途溜走。'},
{id:'new_direct',message:'别夸大其词，陪我好好说话就行。'},
{id:'new_topic',message:'先不聊游戏了，讲个很短的冷笑话吧。'}];let out=[];
for(const item of cases){let t=Date.now();try{out.push({...item,result:await runAgent({kind:'chat',message:item.message,memories:[],history:[],conversation:item.conversation??[],mind:{persona:'温柔陪伴'}},cfg)});}catch(e){out.push({...item,error:e.message});}out.at(-1).ms=Date.now()-t;console.log(item.id,out.at(-1).result?.text??out.at(-1).error);writeFileSync(new URL('../evidence/companion-actions-20260914/final-unseen.json',import.meta.url),JSON.stringify(out,null,2));}
