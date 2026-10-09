// Local integration fixture only. Not a model; never shipped as the default backend.
import {createServer,runAgent} from './server.mjs';
const config={provider:'ollama',url:'http://fixture.invalid',model:'fixture'};
const fake=async(_url,options)=>{
  const body=JSON.parse(options.body);
  if(body.messages.at(-1).role==='user') return {ok:true,json:async()=>({message:{role:'assistant',content:'',tool_calls:[{function:{name:'read_training',arguments:{}}},{function:{name:'propose_memory',arguments:{text:'我喜欢具体鼓励'}}}]}})};
  return {ok:true,json:async()=>({message:{content:'{"text":"姐姐，测试服务已读取训练数据。","action":"cheer"}'}})};
};
const server=createServer(config,(c)=>runAgent(c,config,fake));
server.listen(18766,'127.0.0.1',()=>console.log('Fixture ready on 18766'));
