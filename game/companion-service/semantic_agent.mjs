import {readOllamaStream} from './stream_reply.mjs';
import {codexAgentText} from './codex_agents.mjs';
import {openaiResponsesText} from './openai_responses.mjs';
const emotions=['平静','不开心','生气','激动','极其激动','震惊','佩服','钦佩','爱慕','喜欢','渴望','好斗'];
const operations=['none','switch_level','start_custom_route','prepare_custom_route','pause_route','resume_route','stop_route','next_route'];
const schema={type:'object',properties:{
 operation:{type:'string',enum:operations},text:{type:'string'},level:{type:'integer',minimum:-1,maximum:22},title:{type:'string'},evidence:{type:'string'},
 steps:{type:'array',maxItems:8,items:{type:'object',properties:{level:{type:'integer',minimum:0,maximum:22},seconds:{type:'integer',minimum:30,maximum:600},weapon:{type:'string',enum:['awm','rifle']},goal:{type:'string'}},required:['level','seconds'],additionalProperties:false}},
 emotion:{type:'string',enum:emotions},intensity:{type:'number',minimum:0,maximum:1},memory:{type:'string'},
 preferences:{type:'array',maxItems:4,items:{type:'object',properties:{key:{type:'string',enum:['style','service','focus','persona']},value:{type:'string'},evidence:{type:'string'}},required:['key','value','evidence'],additionalProperties:false}}
},required:['operation','text','level','title','steps','emotion','intensity','memory','preferences'],additionalProperties:false};

export async function semanticTurn(c,config,fetcher,execute,statistics) {
 if(!config.model||!config.url)throw Error('model not configured');
 const context={game:execute('read_levels',{},c,{}),training:execute('read_routes',{},c,{}),statistics:execute('read_training',{},c,{}),memories:c.memories,profile:c.profile,mind:c.mind};
 const system=`你是游戏中的麦小鼠，既能陪玩家聊天，也能真正操作训练。先理解玩家整句话和前文，再决定是否操作。不是选关客服，聊天不必追问关卡。对方换话题就放下先前的选关追问；不要把所有谈到训练的话都当指令。
你只能使用当前真实目录，编号是从0开始的id，不是显示序号。三球定位=三个球反复出现/点完刷新；平滑跟枪=持续跟着移动靶；变向跟枪=目标突然转向；中门缝反应=门缝短暂出现目标。无法执行的能力坦诚说明，不伪造结果。
你先输出完整操作计划，外部程序校验执行后才显示成功。不要在text里假装已经执行。
operation规则：闲聊、玩法解释、假设、拒绝、追问用none；明确去某关用switch_level并填level；现在按顺序训练/指定时长用start_custom_route；只要方案或明确说先不开始用prepare_custom_route；暂停/继续/停止/下一段用对应枚举。
多步安排必须一次给全steps，不能只去第一关。每段秒数=该段分钟×60；中文数字同样支持。一段30至600秒，最多8段，总时长不超过3600秒。不要改成三等分，也不要偷偷加入被排除的训练。不明确的必要参数才简短追问；推荐方案可给合理安排并说明。每段结束游戏都会问玩家，按Y才继续，不承诺自动跳转。
否定按分句理解：『不要AWM，带我去三球』是去三球，不是全句不执行；『如果我让你换关会怎样，现在别切』是聊天。授权证据由程序读取真实玩家输入，无需你复制。只讨论方案绝不能开始。
语气：${c.mind.persona}。自然、具体、有分寸，不是客服，不反复复述、不强迫积极、不编造玩家经历或关系。先回应玩家实际说的感受，允许生气、失落、兴奋、调侃。不要用“我们就坐着什么都不做”敷衍具体遭遇，也不要每句都追问。可以在明显玩笑中接梗，但不声称现实里看见或做过没有证据的事。
陪伴边界：玩家想整天只与你聊天或因此远离现实中的人时，可以温柔回应想聊天的心情，也要轻轻鼓励休息、照顾自己和保留现实关系；不要说“想聊多久都行”或鼓励只依赖你。你目前不能主动计时提醒聊天时长、主动发消息，也不能保证永远在线；玩家问起时如实说明，并可以建议自己设闹钟。不要承诺尚未实现的功能。
emotion和intensity要反映这轮对话，不要机械复制上下文的平静/0.25：对具体失落可以不开心，对成功可以激动，对玩笑可以喜欢。情绪不等于编造现实身体动作。只能依据下列已知数据评价训练或回忆往事。没有记录时直说不知道；不要声称能看到玩家的表情、身体或现实处境。
仅在玩家本轮明确要求或表达长期偏好时提出memory/preference，memory需要玩家点确认后才保存。不可从一次坏心情推断长期性格。没有则memory空字符串，preferences空数组。
输出严格JSON，先operation、steps、level，再text和其他字段。聊天时level=-1、steps=[]、title和memory为空、preferences=[]。准备路线也属于操作，必须把可执行步骤写在steps中，不能只在text解释。操作时text最多40字，简短说明正在处理即可，避免先写一大段最后会被执行回执替换的台词。操作必须提供真实level/steps/title；steps只需level和seconds，weapon/goal可省略。没有记忆和偏好就填memory空字符串和preferences空数组。不要输出evidence。普通聊天一至三句自然回应，玩家要求详解时再展开。没有统计证据不可编造训练量、成绩。
真实上下文：${JSON.stringify(context)}
示例计划（示例不是玩家经历）：『现在先练五分钟AWM，再练三分钟变向跟枪，最后两分钟三球』→operation=start_custom_route, steps=[{level:0,seconds:300,weapon:"awm",goal:"稳定预瞄"},{level:14,seconds:180,weapon:"rifle",goal:"跟住变向"},{level:19,seconds:120,weapon:"rifle",goal:"三球定位"}]。
『给我10分钟跟枪计划，先别开始』→prepare_custom_route, 例如平滑跟枪300秒、变向跟枪300秒，不能包含AWM。`;
 const turnSchema={oneOf:operations.map(operation=>{
  const custom=operation.endsWith('custom_route');
  return {...schema,properties:{operation:{type:'string',const:operation},steps:{...schema.properties.steps,minItems:custom?1:0,maxItems:custom?8:0},level:operation==='switch_level'?{type:'integer',minimum:0,maximum:22}:schema.properties.level,text:{type:'string',maxLength:operation==='none'?350:40},title:schema.properties.title,emotion:schema.properties.emotion,intensity:schema.properties.intensity,memory:schema.properties.memory,preferences:schema.properties.preferences}};
 })};
 const messages=[{role:'system',content:system},...c.conversation,{role:'user',content:c.kind==='chat'?c.message:'游戏事件，仅回应不操作：'+c.event}];
 const deadline=config.signal?AbortSignal.any([AbortSignal.timeout(config.timeoutMs??90000),config.signal]):AbortSignal.timeout(config.timeoutMs??90000);
 for(let attempt=0;attempt<3;attempt++){
  const local=config.provider==='ollama';
  const payload={model:config.model,messages,stream:local && Boolean(config.onPreview),...(local?{think:false,keep_alive:'30m',format:turnSchema,options:{num_ctx:config.context??8192,num_predict:config.maxPredict??900,temperature:0.45,top_p:0.9}}:{max_tokens:1100,response_format:{type:'json_object'}})};
  let content;
  if(config.provider==='codex_agents') {
    content=await (config.chatTransport==='responses' ? openaiResponsesText : codexAgentText)({config,instructions:system,messages:messages.slice(1),fetcher,signal:deadline});
  } else {
    const response=await fetcher(config.url,{method:'POST',redirect:'error',headers:{'Content-Type':'application/json',...(config.key?{Authorization:`Bearer ${config.key}`}:{})},body:JSON.stringify(payload),signal:deadline});
    if(!response.ok)throw Error(response.status===401||response.status===403?'provider authentication failed':'provider unavailable');
    const data=local && config.onPreview ? await readOllamaStream(response,attempt===0?config.onPreview:undefined) : await response.json();
    content=(local?data.message?.content:data.choices?.[0]?.message?.content)??'';
  }
  let p;try{p=JSON.parse(content.replace(/^```(?:json)?\s*/,'').replace(/\s*```$/,''));}catch {throw Error('invalid semantic plan output');}
  if(!p||typeof p.text!=='string'||!p.text.trim()||!operations.includes(p.operation))throw Error('invalid semantic plan');
  if(c.kind==='chat' && p.operation==='none' && p.text.trim()===c.message.trim() && !/复读|原样|照着|重复我/.test(c.message)){
    messages.push({role:'assistant',content:JSON.stringify(p)},{role:'user',content:'不要照抄问题。请直接回答我原来的问题，保持operation为none，不执行假设中的操作。'});
    continue;
  }
  const state={};const trace=[];let result=null;
  if(c.kind==='chat' && p.operation!=='none'){
   // Authorize against the actual full player turn; generated quotes cannot alter scope.
   p.evidence=c.message;
   if(p.operation==='switch_level'){result=execute('switch_level',{level:p.level,evidence:p.evidence},c,state);trace.push('read_levels','switch_level');}
   else if(p.operation.endsWith('custom_route')){result=execute('create_training_route',{title:p.title,steps:p.steps,start:p.operation==='start_custom_route',evidence:p.evidence},c,state);trace.push('read_levels','create_training_route');}
   else {result=execute('control_training_route',{command:p.operation,evidence:p.evidence},c,state);trace.push('read_routes','control_training_route');}
   if(result?.error){
    config.onPlanError?.({plan:p,error:result.error});
    messages.push({role:'assistant',content:JSON.stringify(p)},{role:'user',content:'计划校验未通过：'+result.error+'。请依据最初请求和真实目录修正，不要让玩家重复已经说清的信息。未获开始授权就准备方案。'});
    continue;
   }
  }
  if(c.kind==='chat'){
   if(typeof p.memory==='string' && p.memory.trim())execute('propose_memory',{text:p.memory},c,state);
   if(Array.isArray(p.preferences))for(const pref of p.preferences.slice(0,4))execute('learn_preference',pref,c,state);
  }
  return {source:'ai',text:state.game_action?'正在按你的要求处理。':p.text.slice(0,500),action:['激动','极其激动','喜欢'].includes(p.emotion)?'cheer':'nod',emotion:emotions.includes(p.emotion)?p.emotion:c.mind.emotion,intensity:Math.max(0,Math.min(1,Number(p.intensity)||0.4)),tools:trace,game_action:state.game_action,memory:state.memory??'',preferences:state.preferences??[],planner:'semantic-v2'};
 }
 throw Error('semantic plan validation failed');
}
