import {writeFileSync} from 'node:fs';
const model=process.argv[2]??'qwen3.5:9b';
const r=await fetch('http://127.0.0.1:11435/api/pull',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({model,stream:true})});
if(!r.ok)throw Error(await r.text());
let buffer='',last='';
for await(const chunk of r.body){buffer+=new TextDecoder().decode(chunk);const lines=buffer.split('\n');buffer=lines.pop();for(const line of lines.filter(Boolean)){const e=JSON.parse(line);if(e.error)throw Error(e.error);const status=e.total?`${e.status} ${Math.floor((e.completed||0)/e.total*10)*10}%`:e.status;if(last!==status){console.log(status);last=status;}writeFileSync(new URL('../evidence/companion-actions-20260914/model-pull.json',import.meta.url),JSON.stringify({model,...e}));}}

