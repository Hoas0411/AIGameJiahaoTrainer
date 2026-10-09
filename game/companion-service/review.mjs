// Separate factual inspection from character writing. It never invents a replacement.
export async function reviewReply(context,text,config,fetcher,signal) {
  // Relationship pressure is inappropriate even when a role model calls it banter.
  if(/你(?:总|一直|最近|都|又|很久)[^。！？]{0,18}(?:不出现|不来|没来|不找我|没找我|不陪我|偷懒)/.test(text)) return {unsupported:true,reason:'不要声称玩家缺席、疏远或偷懒来索取陪伴；回应本句的实际内容。'};
  const payload={model:config.model,stream:false,think:false,format:{type:'object',properties:{unsupported:{type:'boolean'},reason:{type:'string'}},required:['unsupported','reason']},options:{num_ctx:config.context??4096,num_predict:240,temperature:0},messages:[
    {role:'system',content:'你是事实审核员，不扮演角色。只拦截四类关键错误：凭空给玩家编姓名、年龄、生日或身份；凭空断言过去共同经历或长期性格；没有数据却评价训练表现、数字、进步；没有记忆却声称记得原因。玩家要求评价不代表提供了数据。当前事件的正常口语概括、情感理解、建议、祝愿、说话者态度、明显拟人物件的笑话不在拦截范围，不抠字眼。只输出JSON：unsupported是否有上述关键错误，reason指出具体错误；没有就false。不要改写回复。'},
    {role:'user',content:JSON.stringify({player_message:'我的成绩怎么样？',known_memories:[],recent_conversation:[],reply_to_check:'你命中率很高，已经很厉害了。'})},
    {role:'assistant',content:'{"unsupported":true,"reason":"玩家只询问成绩，没有提供命中率。回复断言命中率高、很厉害，缺少数据。"}'},
    {role:'user',content:JSON.stringify({player_message:'刚测了80%的命中率，我很开心。',known_memories:[],recent_conversation:[],reply_to_check:'八成命中，难怪你开心。'})},
    {role:'assistant',content:'{"unsupported":false,"reason":"命中率和开心都来自玩家本句。"}'},
    {role:'user',content:JSON.stringify({player_message:context.message,known_memories:context.memories,recent_conversation:context.conversation,reply_to_check:text})}
  ]};
  const response=await fetcher(config.url,{method:'POST',redirect:'error',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload),signal});
  if(!response.ok)throw Error('review provider unavailable');
  const data=await response.json();
  const result=JSON.parse(data.message.content);
  if(typeof result.unsupported!=='boolean')throw Error('invalid review output');
  return result;
}
