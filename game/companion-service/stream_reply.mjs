// Read local NDJSON incrementally. Only conversational text can be previewed;
// operation plans remain invisible until the existing validation has completed.
export function textPreview(content) {
 if(!/^\s*\{\s*"operation"\s*:\s*"none"\s*,/.test(content))return '';
 const m=content.match(/"text"\s*:\s*"((?:\\.|[^"\\])*)/);if(!m)return '';
 try{return JSON.parse('"'+m[1]+'"').slice(0,500);}catch{return '';}
}
export async function readOllamaStream(response,onPreview) {
 if(!response.body)return response.json();
 let buffer='',content='',last='',final=null;const decoder=new TextDecoder();
 const consume=line=>{if(!line.trim())return;const chunk=JSON.parse(line);if(chunk.error)throw Error('provider stream failed');content+=chunk.message?.content??'';if(content.length>32000)throw Error('model output too large');const preview=textPreview(content);if(preview && preview!==last){last=preview;onPreview?.(preview);}if(chunk.done)final=chunk;};
 for await(const bytes of response.body){buffer+=decoder.decode(bytes,{stream:true});if(buffer.length>65536)throw Error('model stream too large');let at;while((at=buffer.indexOf('\n'))>=0){consume(buffer.slice(0,at));buffer=buffer.slice(at+1);}}
 buffer+=decoder.decode();consume(buffer);if(!final)throw Error('incomplete model stream');return {...final,message:{content}};
}
