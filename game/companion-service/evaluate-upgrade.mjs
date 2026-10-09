import {readFileSync,writeFileSync} from 'node:fs';
import {runAgent} from './server.mjs';
const config=JSON.parse(readFileSync(new URL('./config.local.json',import.meta.url),'utf8'));
if(config.provider!=='ollama' || !/^http:\/\/(127\.0\.0\.1|localhost)(:|\/)/.test(config.url)) throw Error('Evaluation only uses configured local model');
const candidates=JSON.parse(readFileSync(new URL('../evidence/companion-20260914/route-candidates.json',import.meta.url),'utf8'));
const output=[];
for(const persona of ['温柔陪伴','活泼搭档','沉静教练']) {
  for(const message of ['今天好累，不想听大道理，你陪我待一会儿就好。','我想练15分钟跟枪，帮我安排几套完整路线。']) {
    const request={kind:'chat',message,profile:{role:'男威龙',address:'阿豪',partner:'训练搭档',style:persona},mind:{persona,preferences:{}},memories:[],history:[],conversation:[],training:{candidates}};
    const started=Date.now();
    try {output.push({persona,message,result:await runAgent(request,{...config,timeoutMs:90000}),milliseconds:Date.now()-started});}
    catch(error) {output.push({persona,message,error:error.message,milliseconds:Date.now()-started});}
    writeFileSync(new URL('../evidence/companion-20260914/live-dialogue.json',import.meta.url),JSON.stringify(output,null,2));
    console.log(JSON.stringify(output.at(-1)));
  }
}
