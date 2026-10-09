import {readFileSync,writeFileSync} from 'node:fs';
import {runAgent} from './server.mjs';
const config=JSON.parse(readFileSync(new URL('./config.local.json',import.meta.url),'utf8'));
const cases=[['fatigue','今天又练砸了，先别教我，我就想发会牢骚。'],['specific','今天连续三次打中了移动靶，我有点得意。'],['tease','麦小鼠，你是不是偷偷替靶子加班了，怎么一直躲我？'],['company','今天没有特别的事，就想跟你待一会儿。'],['correction','别每次都叫我哥哥，正常说话就好。'],['memory','你还记得我为什么不喜欢别人催我吗？']];
const results=[];
for(const [id,message] of cases){const start=Date.now();try{const result=await runAgent({kind:'chat',message,profile:{partner:'训练搭档',style:'温柔具体'},mind:{persona:'温柔陪伴'},memories:[],history:[],conversation:[]},config);results.push({id,message,result,ms:Date.now()-start});}catch(e){results.push({id,message,error:e.message,ms:Date.now()-start});}writeFileSync(new URL('../evidence/companion-actions-20260914/baseline.json',import.meta.url),JSON.stringify(results,null,2));console.log(id,results.at(-1).ms);}
