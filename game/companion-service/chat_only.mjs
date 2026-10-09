import {openaiResponsesText} from './openai_responses.mjs';

const emotions = ['平静','不开心','生气','激动','极其激动','震惊','佩服','钦佩','爱慕','喜欢','渴望','好斗'];

export async function chatOnlyTurn(c, config, fetcher, execute) {
  const olderPreferences = c.conversation.slice(0,-12).filter(m => m.role === 'user' && /我.{0,16}(?:喜欢|不喜欢|讨厌|偏好)/.test(m.content)).slice(-8).map(m => m.content.slice(0,160));
  const instructions = `你是游戏里的麦小鼠，是玩家的聊天伙伴。语气：${c.mind.persona}。温柔、自然、具体；先回应玩家真正说的事，不要像客服，也不必每句话追问。你不能切换关卡、编排或启动训练，也不能在以后替玩家执行这些操作；玩家请求时直接说明当前只负责聊天，不要说已经准备好计划或等玩家说“开始”就会执行。
你看不到玩家的现实动作或表情，不能编造共同经历、训练成绩或记忆。可以亲近，但不要鼓励玩家只依赖你或放弃现实关系。不能承诺永远在线、主动发消息或计时提醒；如被问到，如实说明。遇到自伤风险，先关心当前安全并建议联系身边可信任的人或当地急救服务。
历史对话仅以输入中的记录为准。以下是玩家已确认保存的记忆：${JSON.stringify(c.memories)}。个人资料：${JSON.stringify(c.profile)}。当前陪伴偏好：${JSON.stringify(c.mind.preferences)}。较早的聊天片段（只是历史，不等于已确认的长期记忆）：${JSON.stringify(olderPreferences)}。没有记录的事就说不知道。
只输出JSON对象：text为一至三句自然回复，emotion从${JSON.stringify(emotions)}选择，intensity为0到1的数字；memory默认为空字符串，只有玩家本轮明确要求记住某事时才写一句待确认记忆。记忆要经过玩家确认才保存，因此text不能说“已经记住”，应说“我可以记下这件事，请确认”。preferences默认为空数组，只有玩家本轮明确表达长期偏好时才写对象，字段key只能是style、service、focus、persona，value为偏好值，evidence须逐字取自玩家本轮消息。不能把一次心情当成长期偏好。`;
  const messages = [...c.conversation.slice(-12), {role:'user', content:c.kind === 'chat' ? c.message : `游戏事件：${c.event}。只作简短回应。`}];
  const deadline = config.signal ? AbortSignal.any([AbortSignal.timeout(config.timeoutMs ?? 90000), config.signal]) : AbortSignal.timeout(config.timeoutMs ?? 90000);
  const content = await openaiResponsesText({config:{...config,chatMaxOutputTokens:450},instructions,messages,fetcher,signal:deadline});
  let p;
  try { p = JSON.parse(content); } catch { throw Error('invalid chat output'); }
  if (!p || typeof p.text !== 'string' || !p.text.trim()) throw Error('invalid chat output');
  const state = {};
  if (c.kind === 'chat') {
    if (typeof p.memory === 'string' && p.memory.trim() && /记住|记下来|记得我/.test(c.message)) {
      const memory = p.memory.replace(/[,，]?待确认[。.]?$/,'').trim();
      if (memory) execute('propose_memory',{text:memory},c,state);
    }
    if (Array.isArray(p.preferences)) for (const pref of p.preferences.slice(0,4)) execute('learn_preference',pref,c,state);
  }
  return {source:'ai', text:p.text.trim().slice(0,500), action:['激动','极其激动','喜欢'].includes(p.emotion)?'cheer':'nod', emotion:emotions.includes(p.emotion)?p.emotion:c.mind.emotion, intensity:Math.max(0,Math.min(1,Number(p.intensity)||0.4)), tools:[], memory:state.memory??'', preferences:state.preferences??[], planner:'chat-only'};
}
