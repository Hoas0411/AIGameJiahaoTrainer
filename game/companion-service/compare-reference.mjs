import {readFileSync,writeFileSync} from 'node:fs';
import {runAgent} from './server.mjs';
const config=JSON.parse(readFileSync(new URL('./config.local.json',import.meta.url),'utf8'));
if(config.provider!=='ollama'||!config.url.startsWith('http://127.0.0.1:'))throw Error('local model only');
const message='你居然记得！我之前很紧张，不过演讲好像很顺利。CEO还特地告诉我，我提出的观点很好！';
const result=await runAgent({kind:'chat',message,profile:{partner:'训练搭档',address:'',style:'温柔具体'},mind:{persona:'温柔陪伴'},memories:['玩家今天要做演讲，之前有些紧张。'],history:[],conversation:[{role:'assistant',content:'对了，你今天的演讲怎么样了？',source:'ai'}]}, {...config,timeoutMs:90000});
const evidence={reference:'https://nomi.ai/',image:'references/nomi-official-memory.webp',condition:'官方宣传图的同语义输入译为中文；不是登录产品实测',message,result};
writeFileSync(new URL('../evidence/companion-20260914/reference-stimulus-comparison.json',import.meta.url),JSON.stringify(evidence,null,2));
console.log(JSON.stringify(evidence));
