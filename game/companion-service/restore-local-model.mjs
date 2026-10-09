// Repair the already-configured model through Ollama's official pull mechanism.
import {readFileSync,writeFileSync} from 'node:fs';
const config=JSON.parse(readFileSync(new URL('./config.local.json',import.meta.url),'utf8'));
if(config.provider!=='ollama' || !/^http:\/\/(127\.0\.0\.1|localhost)(:|\/)/.test(config.url)) throw Error('Local Ollama configuration required');
const response=await fetch(new URL('/api/pull',config.url),{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({model:config.model,stream:true})});
if(!response.ok) throw Error(`pull status ${response.status}`);
let buffer='',last='';
for await (const chunk of response.body) {
  buffer+=new TextDecoder().decode(chunk);
  const lines=buffer.split('\n');buffer=lines.pop();
  for(const line of lines.filter(Boolean)) {
    const event=JSON.parse(line);
    if(event.error) throw Error(event.error);
    const status=event.total?`${event.status} ${Math.floor((event.completed||0)/event.total*10)*10}%`:event.status;
    if(status!==last) {console.log(status);last=status;}
    writeFileSync(new URL('../evidence/companion-20260914/model-download-status.json',import.meta.url),JSON.stringify({model:config.model,...event}));
  }
}
