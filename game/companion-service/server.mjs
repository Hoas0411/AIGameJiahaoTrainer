import {semanticTurn} from './semantic_agent.mjs';
import {chatOnlyTurn} from './chat_only.mjs';
import {instructionEvidence,routeSteps,excludedLevel,durationConstraint,fitSuggestedDuration} from './intent.mjs';
import http from 'node:http';
import {reviewReply} from './review.mjs';
import {speechReady,transcribe} from './speech.mjs';
import {readFileSync, existsSync} from 'node:fs';
import {fileURLToPath} from 'node:url';

const clip = (v, n = 500) => typeof v === 'string' ? v.slice(0, n) : '';
const numericFields = (input, keys) => Object.fromEntries(keys.map(k=>[k,Math.max(0,Math.min(1e12,Number(input?.[k])||0))]));
const emotions = ['平静','不开心','生气','激动','极其激动','震惊','佩服','钦佩','爱慕','喜欢','渴望','好斗'];
const personas = {
  '温柔陪伴':'先接住玩家具体的感受，少说套话。温柔但有自己的看法；亲近自然，不每句话都叫昵称。',
  '活泼搭档':'轻松、机灵、偶尔接梗；只为具体发生的事情兴奋。玩家失落时收起玩笑，不做夸夸机器。',
  '沉静教练':'简短、沉稳、有分寸。先确认玩家要倾听还是建议；需要训练建议时只给一个可执行小步骤。'
};
const preferenceValues = {style:['温柔具体','活泼夸夸','轻松调侃','安静简短'],service:['先陪伴，暂不建议训练','陪伴与训练建议'],focus:['laser','tracking','mixed'],persona:Object.keys(personas)};
function mindContext(v = {}) {
  const preferences = {};
  for (const key of ['service','style','focus','address']) {
    if (v.preferences?.[key]?.value !== undefined) preferences[key] = {value:clip(v.preferences[key].value,80),source:clip(v.preferences[key].source,160)};
  }
  return {persona:Object.hasOwn(personas,v.persona) ? v.persona : '温柔陪伴', emotion:emotions.includes(v.emotion) ? v.emotion : '平静', intensity:Math.max(0,Math.min(1,Number(v.intensity)||0.25)),preferences,last_topic:clip(v.last_topic,120)};
}
function trainingContext(v = {}) {
  const cleanRoute=r=>({id:clip(r?.id,60),title:clip(r?.title,60),reason:clip(r?.reason,160),steps:Array.isArray(r?.steps)?r.steps.slice(0,8).filter(s=>Number.isInteger(s?.level)&&s.level>=0&&s.level<23).map(s=>({level:s.level,title:clip(s.title,60),seconds:Math.max(30,Math.min(600,Number(s.seconds)||300)),weapon:clip(s.weapon,20),goal:clip(s.goal,100)})):[]});
  return {status:clip(v.status,160),step:Number(v.step)||0,elapsed:Math.max(0,Number(v.elapsed)||0),pending:v.pending===true,suspended:v.suspended===true,
    active:v.active?.id?cleanRoute(v.active):null,candidates:Array.isArray(v.candidates)?v.candidates.slice(0,4).filter(r=>['laser','tracking','mixed','custom'].includes(r?.id)).map(cleanRoute):[]};
}
function trainingRecord(v) {
  return {...numericFields(v,['level','seconds','shots','hits','headshots','kills','abilities','unix_time']), success:v.success === true,
    drill_metrics:numericFields(v.drill_metrics,['drill','reaction_ms','reaction_hits','opportunities','audio_correct','audio_attempts','explosive_hits','jump_height','apex_seconds','dash_distance'])};
}
export function normalize(input) {
  if (!input || typeof input !== 'object' || !['chat', 'event'].includes(input.kind)) throw Error('invalid request');
  const p = input.profile ?? {};
  return {
    kind: input.kind, message: clip(input.message, 1500), event: clip(input.event, 300),
    mind: mindContext(input.mind), training: trainingContext(input.training),
    game: {current_level:Number(input.game?.current_level)||0,running:input.game?.running===true,levels:Array.isArray(input.game?.levels)?input.game.levels.filter(v=>Number.isInteger(v?.id)&&v.id>=0&&v.id<23&&typeof v.name==='string').slice(0,23).map(v=>({id:v.id,name:clip(v.name,50)})):[]},
    profile: {role: clip(p.role, 40), address: clip(p.address, 40), style: clip(p.style, 100), partner: clip(p.partner, 40)},
    memories: Array.isArray(input.memories) ? input.memories.filter(v => typeof v === 'string').slice(-30).map(v => clip(v, 200)) : [],
    history: Array.isArray(input.history) ? input.history.slice(-100).filter(v => v && typeof v === 'object').map(trainingRecord) : [],
    conversation: Array.isArray(input.conversation) ? input.conversation.slice(-240).filter(v => v && ['user', 'assistant'].includes(v.role) && v.source !== 'fallback').map(v => ({role:v.role, content:clip(v.content,1500)})) : []
  };
}

export function summary(history) {
  const levels = {};
  for (const r of history) {
    const v = levels[r.level] ??= {sessions:0, kills:0, shots:0, hits:0, seconds:0};
    v.sessions++; v.kills += r.kills; v.shots += r.shots; v.hits += r.hits; v.seconds += r.seconds;
  }
  const last=history.at(-1);
  const previous=last ? history.slice(0,-1).filter(r=>r.level===last.level && Math.abs(r.seconds-last.seconds)<=Math.max(5,last.seconds*0.1)).at(-1) : null;
  const comparable=previous && last.shots>0 && previous.shots>0 ? {
    level:last.level, latest_accuracy:Math.round(last.hits/last.shots*100), previous_accuracy:Math.round(previous.hits/previous.shots*100),
    accuracy_change_percentage_points:Math.round((last.hits/last.shots-previous.hits/previous.shots)*100),
    note:'同关卡、时长相近的最近两轮；不代表长期趋势，也未控制全部难度/配装差异'
  } : null;
  return {scope:'最近最多100轮已结算训练；不同关卡和时长不可直接比较击倒数', sessions:history.length, levels, recent:history.slice(-5),comparable};
}

const tool = (name, description, properties = {}, required = []) => ({type:'function',function:{name,description,parameters:{type:'object',properties,required,additionalProperties:false}}});
const tools = [
  tool('read_training', '读取游戏实际记录的训练统计和最近五轮。回答进步问题前调用。'),
  tool('read_memories', '读取玩家明确保存的偏好和共同记忆。'),
  tool('read_companion_state', '读取玩家选择的人设、培养偏好及来源、当前情绪。'),
  tool('learn_preference', '从玩家本轮明确表达的偏好理解相处方式。必须引用本轮原文作为evidence，不从暂时情绪或推测贴标签；可在培养页纠正和重置。', {key:{type:'string',enum:Object.keys(preferenceValues)},value:{type:'string'},evidence:{type:'string'}}, ['key','value','evidence']),
  tool('read_routes', '读取游戏可以实际运行的三套完整路线与当前路线状态。'),
  tool('read_levels', '读取真实关卡目录和玩家所在关卡。'),
  tool('switch_level', '玩家明确要求去某个关卡时，提交真实换关动作；id必须来自read_levels。目标不明确先追问。不用于讨论、否定或假设。客户端实际加载后才显示完成。', {level:{type:'integer',minimum:0,maximum:22},evidence:{type:'string',description:'引用玩家本轮肯定操作的原文，不要引用被否定的操作'}}, ['level']),
  tool('plan_training', '按玩家需要编排三套真实训练路线。只准备候选；玩家在F7路线页选择开始。每段到时由气泡询问，Y确认换关，忽略则继续。', {focus:{type:'string',enum:['laser','tracking','mixed']},minutes:{type:'integer',minimum:3,maximum:30}}, ['focus','minutes']),
  tool('create_training_route', '按玩家描述的目标、顺序和逐段时长编排自定义路线。先read_levels查关卡；只用支持的关卡。要求现在开始时start=true，只讨论/预览时start=false。每段结束仍需玩家按Y确认。不要把每段时长当总时长，也不要加入玩家排除的练习。', {
    title:{type:'string'},start:{type:'boolean'},evidence:{type:'string',description:'本轮玩家要求编排或开始的原文'},
    steps:{type:'array',minItems:1,maxItems:8,items:{type:'object',properties:{level:{type:'integer',minimum:0,maximum:22},seconds:{type:'integer',minimum:30,maximum:600},weapon:{type:'string',enum:['awm','rifle']},goal:{type:'string'}},required:['level','seconds'],additionalProperties:false}}
  },['title','start','evidence','steps']),
  tool('control_training_route', '控制当前已开始路线：暂停、继续、结束或下一段。仅对玩家本轮操作请求调用。', {command:{type:'string',enum:['pause_route','resume_route','stop_route','next_route']},evidence:{type:'string'}},['command','evidence']),
  tool('propose_memory', '仅提议保存本轮玩家明确表达的长期偏好；需要玩家点击确认，不代表已保存。', {text:{type:'string'}}, ['text'])
];

function confirmedLevel(c) {
  if(!/^(是的|对|没错|好|好的|就这个|就它|可以)[。！!，,\s]*$/.test(c.message.trim()))return -1;
  const previous=c.conversation.filter(m=>m.role==='assistant').at(-1)?.content??'';
  if(!/[？?吗]/.test(previous) || !/你是指|(?:想|要|需要)(?:去|练|切换|换到|进入)|(?:换到|切到|进入).*(?:吗|[？?])/.test(previous))return -1;
  const named=c.game.levels.filter(l=>previous.includes(l.name));
  return named.length===1?named[0].id:-1;
}
export function executeTool(name, args, context, state) {
  if (name === 'read_training') return summary(context.history);
  if (name === 'read_memories') return {profile:context.profile, memories:context.memories};
  if (name === 'read_companion_state') return context.mind;
  if (name === 'learn_preference' && context.kind === 'chat') {
    const evidence=clip(args?.evidence,160).trim();
    if(!Object.hasOwn(preferenceValues,args?.key) || !preferenceValues[args.key].includes(args.value) || evidence.length<2 || !context.message.includes(evidence)) return {error:'invalid preference or evidence'};
    state.preferences ??= [];
    if(state.preferences.length>=4) return {error:'preference limit'};
    const preference={key:args.key,value:args.value,source:evidence};
    state.preferences.push(preference);
    return {status:'ready_for_client',preference,correction:'玩家可在培养页查看和重置'};
  }
  if (name === 'read_routes') return context.training;
  if (name === 'read_levels') return context.game;
  if (name === 'switch_level' && context.kind === 'chat') {
    if (!Number.isInteger(args?.level) || !context.game?.levels.some(v=>v.id===args.level)) return {error:'unknown level'};
    if (excludedLevel(context,args.level)) return {error:'player excluded this level'};
    if (!instructionEvidence(context,args.evidence) && confirmedLevel(context)!==args.level) return {error:'no current switch instruction'};
    if(state.game_action)return {error:'one game operation per turn; use a route for multiple stages'};
    state.game_action={kind:'switch_level',level:args.level};
    return {status:'pending_client_execution',action:state.game_action};
  }
  if (name === 'create_training_route' && context.kind === 'chat') {
    let steps=routeSteps(args,context);
    if(steps)steps=fitSuggestedDuration(context.message,steps);
    if(steps && durationConstraint(context.message,steps))return {error:durationConstraint(context.message,steps)};
    if(steps?.some(step=>excludedLevel(context,step.level)))return {error:'route includes a level excluded by player'};
    if(!steps || typeof args.start!=='boolean' || !instructionEvidence(context,args.evidence))return {error:'invalid route or missing player instruction'};
    if(state.game_action)return {error:'one game operation per turn'};
    if(args.start && /(?:不要|别|暂不|先不|不想)(?:现在|马上|立即)?开始/.test(context.message))return {error:'player explicitly requested a preview, not starting'};
    if(args.start && !/开始|现在|带我|先练|先来|按.*练|就.*练/.test(instructionEvidence(context,args.evidence)))return {error:'only prepare this plan; player did not ask to start now'};
    state.game_action={kind:args.start?'start_custom_route':'prepare_custom_route',title:clip(args.title,60)||'本次训练',steps};
    return {status:'pending_client_execution',action:state.game_action};
  }
  if(name==='control_training_route' && context.kind==='chat') {
    if(!['pause_route','resume_route','stop_route','next_route'].includes(args?.command)||!instructionEvidence(context,args.evidence))return {error:'missing route instruction'};
    if(state.game_action)return {error:'one game operation per turn'};
    state.game_action={kind:args.command};return {status:'pending_client_execution',action:state.game_action};
  }
  if (name === 'plan_training' && context.kind === 'chat') {
    if (!['laser','tracking','mixed'].includes(args?.focus) || !Number.isInteger(args.minutes) || args.minutes<3 || args.minutes>30) return {error:'invalid route parameters'};
    if (!context.training?.candidates?.some(r=>r.id===args.focus)) return {error:'route unavailable in game'};
    // An explicit player request outranks a model guessing the first enum value.
    let selected=args.focus;
    if (/跟枪/.test(context.message) && !/不(?:想|要|喜欢)(?:练)?跟枪/.test(context.message)) selected='tracking';
    else if (/镭射|\bawm?\b/i.test(context.message) && !/不(?:想|要|喜欢)(?:练)?镭射/.test(context.message)) selected='laser';
    else if (/综合/.test(context.message)) selected='mixed';
    if(!context.training.candidates.some(r=>r.id===selected)) return {error:'requested route unavailable'};
    state.route_focus=selected;state.route_minutes=args.minutes;
    return {status:'prepared_for_player_selection',focus:selected,minutes:args.minutes,routes:context.training.candidates.map(r=>({...r,steps:r.steps.map(s=>({...s,seconds:args.minutes*20}))})),next:'三套不同方向的候选，优先推荐指定方向。F7训练路线页选择开始。尚未换关。'};
  }
  if (name === 'propose_memory' && context.kind === 'chat') {
    const value = clip(args?.text,200).trim();
    if (!value) return {error:'empty memory'};
    state.memory = value;
    return {status:'pending_player_confirmation', text:value};
  }
  return {error:'tool not allowed'};
}

export async function runAgent(raw, config, fetcher = fetch) {
  const c = normalize(raw);
  if (!config.model || !config.url) throw Error('model not configured');
  const state = {memory:''};
  const confirmed=confirmedLevel(c);
  const needsTools = c.kind === 'chat';
  // Turn guidance describes the current need; it never supplies canned reply text.
  const guidance=[];
  if (/得意|终于|开心|高兴|成功|做到了|说完了/.test(c.message)) guidance.push('玩家在分享一件成功的事：回应那件具体的事，允许他高兴。不要马上降温、要求谦虚或布置下一项任务。');
  if (/牢骚|别教|不想听|别.*道理|吐槽/.test(c.message)) guidance.push('玩家要倾诉：给他继续说的空间，不让他闭嘴，不安排活动，不给建议。');
  if (/真话|只会夸|别.*夸/.test(c.message)) guidance.push('玩家在要求坦率：可以说明你的真实判断边界，不凭空评价玩家技术、表现或性格，也不继续夸他。');
  if (/加班|偷偷|哈哈|开玩笑/.test(c.message)) guidance.push('玩家可能在开玩笑：接住他话里的梗，不转成对玩家疏远你或偷懒的指责。虚构笑话限于明显拟人的物件，不编造玩家的经历。');
  const levelIntent=needsTools && (confirmed>=0 || /关卡|切换|想去|带我|想练/.test(c.message)) && !/路线|计划/.test(c.message);
  const statsIntent=needsTools && /成绩|进步|表现|评价|准星控制|枪法|水平|数据/.test(c.message) && !/不是.*(枪法|水平|表现)|不(要|想|用).*?(分析|评价|看|建议)/.test(c.message) && !levelIntent;
  if(statsIntent && c.history.length===0) {
    executeTool('read_training',{},c,state);
    return {text:'现在没有已结算的训练数据，我不能凭空评价你的准星。打完一轮后，我可以结合命中记录跟你看。',source:'local',action:'idle',tools:['read_training'],routed_tools:['read_training']};
  }
  const availableTools=tools;
  const messages = [{role:'system',content:
    `优先级：事实诚实 > 回应需求 > 角色语气。不要为了共情假装熟悉，坦诚不知道同样可以亲近。共情不需要编造共同经历。\n`+
    `你是麦小鼠，陪玩家聊天。自然地接住眼前这句话，不当客服，不写小说。${personas[c.mind.persona]}不要只复述或说“嗯”，也不刻意找话题。对方诉苦就听，要独处就道别。
`+
    `你无法看到玩家。不得评价玩家的动作、枪法、专注程度或来访频率。玩笑可以接，但不能为了接梗编造这些事实；坦率也不等于随便批评。不要因玩家离开而抱怨或索取陪伴。${c.memories.length?'以下是确实已知的记忆，涉及相关问题时依据它回答：'+c.memories.join('；'):'你没有任何关于玩家的历史记忆。玩家问记不记得时必须承认不知道，不能编造原因。'}
`+
    `先理解完整一句话和最近对话，再决定聊天、解释、追问还是调用工具。正常闲聊直接回答，不把聊天变成选关表单；玩家换话题就放下上一条未完成的追问。否定只约束被否定的内容，例如不要镭射但想练三球，应按肯定部分操作。复杂内容可结合read_levels/read_training/read_routes；按用户顺序和逐段时长用create_training_route，路线控制用control_training_route。玩家只要方案就准备，不要擅自开始。不要对超出已有工具的操作假装执行。每次工具最多提交一个游戏动作，多步训练应合成一条路线。\n`+
    `本轮回应重点：${guidance.join(" ")}\n`+
    `称呼与相处方式：${JSON.stringify(c.profile)}；玩家明确的偏好：${JSON.stringify(c.mind.preferences)}。不要编造姓名或共同经历。
`+
    (needsTools?'按工具结果回答。换关用read_levels、switch_level；路线用read_routes、plan_training；记忆用propose_memory待玩家确认。工具只提交操作，客户端执行后才算完成。明确偏好用learn_preference并引用原话。成绩先read_training。不要执行假设或否定请求。\n':'')+
    `只输出JSON，text写自然台词，不写括号动作，action是idle/nod/cheer，emotion写情绪，intensity是0到1的强度。`+
    (c.memories.length===0 && /记得|记不记得|还记|忘了/.test(c.message)?'本轮明确没有相关历史记忆。回答必须说明不记得原因，不能猜测任何原因，也不能说以前聊过。':'' )},
    ...(!c.kind || c.kind!=='chat' ? [] : [
      {role:'user',content:'以下仅为语气示范，不是玩家经历：你知道我小时候的外号吗？'},
      {role:'assistant',content:'{"text":"不知道诶，你还没告诉过我。是什么？","action":"idle","emotion":"平静","intensity":0.3}'},
      {role:'user',content:'以下仅为语气示范，不是玩家经历：楼下的小狗今天冲我摇尾巴。'},
      {role:'assistant',content:'{"text":"它这一摇，今天出门都值了。","action":"cheer","emotion":"喜欢","intensity":0.5}'},
      {role:'user',content:'以下仅为语气示范，不是玩家经历：你别用那些大道理搪塞我。'},
      {role:'assistant',content:'{"text":"好，先把道理收起来。你说，我认真听。","action":"nod","emotion":"平静","intensity":0.4}'}
    ]),
    ...c.conversation,
    {role:'user',content:c.kind==='chat'?c.message:'游戏事件：'+c.event}];
  const trace = [];
  const timeout = AbortSignal.timeout(config.timeoutMs ?? 45000);
  const deadline = config.signal ? AbortSignal.any([timeout,config.signal]) : timeout;
  for (let round=0; round<4; round++) {
    const ollama = config.provider === 'ollama';
    const payload = {model:config.model,messages,stream:false,...(ollama?{keep_alive:"30m"}:{}),...(needsTools?{tools:availableTools}:{})};
    if(config.provider==='ollama' && !needsTools) payload.format={type:'object',properties:{text:{type:'string'},action:{type:'string',enum:['idle','nod','cheer']},emotion:{type:'string',enum:emotions},intensity:{type:'number'}},required:['text','action','emotion','intensity'],additionalProperties:false};
    if (ollama) { payload.options = {num_predict:config.maxPredict??300,num_ctx:config.context??8192,temperature:config.temperature??0.35,top_p:0.9,repeat_penalty:1.05,presence_penalty:0.2}; if (!config.model.startsWith('gemma')) payload.think = config.thinking??false; }
    else payload.max_tokens = 600;
    const response = await fetcher(config.url, {method:'POST',redirect:'error',headers:{'Content-Type':'application/json',...(config.key ? {Authorization:`Bearer ${config.key}`} : {})},body:JSON.stringify(payload),signal:deadline});
    if (!response.ok) throw Error(response.status === 401 || response.status === 403 ? 'provider authentication failed' : response.status === 404 ? 'model or endpoint not found' : 'provider unavailable');
    const data = await response.json();
    const msg = ollama ? data.message : data.choices?.[0]?.message;
    if (!msg || typeof msg !== 'object') throw Error('invalid provider response');
    if (Array.isArray(msg.tool_calls) && msg.tool_calls.length) {
      if (msg.tool_calls.length > 4) throw Error('too many tool calls');
      messages.push(msg);
      for (const call of msg.tool_calls) {
        const name = call.function?.name;
        let args = call.function?.arguments ?? {};
        if (typeof args === 'string') { try { args=JSON.parse(args); } catch { args={}; } }
        const result = executeTool(name,args,c,state);
        trace.push(clip(name,50));
        messages.push({role:'tool',...(ollama ? {tool_name:name} : {tool_call_id:call.id}),content:JSON.stringify(result)});
      }
      if(state.game_action) return {text:state.game_action.kind==='switch_level'?'正在切换。':'正在处理训练安排。',action:'idle',source:'ai',tools:trace,game_action:state.game_action};
      continue;
    }
    const content = clip(msg.content,3000).replace(/^```(?:json)?\s*/, '').replace(/\s*```$/, '').trim();
    let parsed, requestId;
    try { parsed = JSON.parse(content); } catch {
      // Models may answer in natural language despite the JSON request. This is still
      // a genuine model reply; restrict its action to idle instead of reporting offline.
      if (content && !/^[{\[```]/.test(content)) parsed = {text:content,action:'idle'};
      else throw Error('invalid model output');
    }
    if (typeof parsed === 'string') parsed = {text:parsed,action:'idle'};
    if (!parsed || typeof parsed.text !== 'string' || !parsed.text.trim()) throw Error('empty model output');
    if(levelIntent && (confirmed>=0 || /带我|想去|想练|切换|进入/.test(c.message)) && !/不要|不用|别|不想|如果|假如|怎么|如何/.test(c.message) && /带你|切换|进入|过去|开始/.test(parsed.text) && !/[？?吗]/.test(parsed.text)) {
      if(round>=2) throw Error('agent step limit');
      messages.push({role:'assistant',content:JSON.stringify(parsed)});
      messages.push({role:'user',content:'你还没有提交实际操作。不要只承诺带我过去。目标明确就调用switch_level，目标不明确就追问。'});
      continue;
    }
    if (config.verifyReplies && config.provider==='ollama' && trace.length===0) {
      const review=await reviewReply(c,parsed.text,config,fetcher,deadline);
      config.onReview?.({text:parsed.text,review});
      if(review.unsupported) {
        if(round>=2) return {text:/记得|生日|上次|知道/.test(c.message)?'这件事我还没有可靠的记忆，你愿意告诉我吗？':'这句我不想凭空下判断。你可以多说一点，我认真听。',source:'local',action:'idle',tools:[],reviewed_fallback:true};
        messages.push({role:'assistant',content:JSON.stringify(parsed)});
        messages.push({role:'user',content:'审核发现这句回复含有缺乏依据的断言：'+review.reason+'。请重新回应我最初的话，不提审核过程，不再重复该断言。只输出规定的JSON。'});
        continue;
      }
    }
    // Small local models sometimes describe a plan without invoking its tool.
    // Complete explicit route intent using the same validated tool, and disclose origin.
    const routedTools=[];
    if(c.kind==='chat' && /路线|训练计划|安排.*训练/.test(c.message) && !/取消|停止|不要.*路线/.test(c.message) && !state.route_focus && c.training.candidates.length) {
      const duration=c.message.match(/(\d+)\s*分钟/);
      const preferred=c.mind.preferences.focus?.value;
      const focus=c.training.candidates.some(r=>r.id===preferred)?preferred:c.training.candidates[0].id;
      const result=executeTool('plan_training',{focus,minutes:duration?Math.max(3,Math.min(30,Number(duration[1]))):15},c,state);
      if(!result.error) {trace.push('plan_training');routedTools.push('plan_training');}
    }
    const finalText=state.route_focus ? `已按${{laser:'AWM镭射',tracking:'跟枪',mixed:'综合'}[state.route_focus]}方向优先编排${state.route_minutes}分钟训练，并保留另两套不同练法。打开F7「训练路线」选择开始；每段到时我会问你，按Y才换关。` : parsed.text.trim();
    return {text:finalText.slice(0, c.kind==='event' ? 140 : 500),action:['nod','cheer','idle'].includes(parsed.action) ? parsed.action : 'idle', memory:state.memory, source:'ai', tools:trace,
      emotion:emotions.includes(parsed.emotion)?parsed.emotion:c.mind.emotion,intensity:Math.max(0.15,Math.min(1,Number(parsed.intensity)||0.5)),route_focus:state.route_focus??'',route_minutes:state.route_minutes??15,preferences:state.preferences??[],routed_tools:routedTools};
  }
  throw Error('agent step limit');
}

export async function runSemanticAgent(raw, config, fetcher = fetch) {
  const c=normalize(raw);
  if (config.chatOnly && config.provider === 'codex_agents' && config.chatTransport === 'responses') return chatOnlyTurn(c,config,fetcher,executeTool);
  return semanticTurn(c,config,fetcher,executeTool,summary(c.history));
}
export function createServer(config, agent = runSemanticAgent) {
  let active = false;
  let speechActive = false;
  let progress = null;
  return http.createServer(async (req,res) => {
    const send=(status,body)=>{res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'});res.end(JSON.stringify(body));};
    // Loopback only. No browser origins or host rebinding; no CORS or public proxy.
    if (req.headers.origin || !/^127\.0\.0\.1(?::\d+)?$/.test(req.headers.host ?? '')) return send(403,{error:'local game only'});
    if(req.method==='GET' && req.url.startsWith('/progress/')){const id=req.url.slice(10);return send(200,progress?.id===id?{text:progress.text}:{text:''});}
    if (req.method==='GET' && req.url==='/health') return send(200,await health(config));
    if (req.method==='POST' && req.url==='/transcribe') {
      if(speechActive) return send(429,{error:'语音识别繁忙'});
      if(!String(req.headers['content-type']).startsWith('audio/wav')) return send(415,{error:'需要 WAV 录音'});
      speechActive=true;
      try {
        const chunks=[]; let size=0;
        for await(const chunk of req) { size+=chunk.length; if(size>384044) return send(413,{error:'录音超过12秒'}); chunks.push(chunk); }
        return send(200,await transcribe(Buffer.concat(chunks),config));
      } catch(error) { return send(503,{error: error.killed ? '语音识别超时，请缩短句子' : (error.message.startsWith('需要') || error.message.startsWith('本机') ? error.message : '本地语音识别失败，请重试')}); }
      finally { speechActive=false; }
    }
    if (req.method!=='POST' || req.url!=='/companion') return send(404,{error:'not found'});
    if (active) return send(429,{error:'busy'});
    if (!String(req.headers['content-type']).startsWith('application/json')) return send(415,{error:'json required'});
    let body='';
    try {
      req.setEncoding('utf8');
      for await (const chunk of req) {body += chunk; if (Buffer.byteLength(body)>131072) return send(413,{error:'too large'});}
      let parsed, requestId;
      try { const raw=JSON.parse(body);parsed=normalize(raw);requestId=typeof raw.request_id==='string' && /^[a-f0-9]{32}$/.test(raw.request_id)?raw.request_id:null; } catch { return send(400,{error:'invalid request'}); }
      if (active) return send(429,{error:'busy'});
      active=true;
      const controller=new AbortController();
      const disconnected=()=>{if(!res.writableEnded)controller.abort();};
      res.on('close',disconnected);
      progress=requestId?{id:requestId,text:''}:null;
      try {const result=await agent(parsed,{...config,signal:controller.signal,...(requestId?{onPreview:text=>{if(progress?.id===requestId)progress.text=text;}}:{})});if(!res.destroyed)send(200,result);}
      catch (error) {if(!res.destroyed)send(503,{error:explainError(error)});}
      finally {res.off('close',disconnected);active=false;progress=null;}
    } catch { if (!res.headersSent) send(400,{error:'incomplete request'}); }
  });
}

export function explainError(error) {
  const message = error?.message ?? '';
  if (message === 'model not configured') return '尚未配置 AI 模型；开关已开启，但服务没有可用模型。';
  if (message === 'provider authentication failed') return '模型服务拒绝了密钥，请检查本机配置中的密钥。';
  if (message === 'model or endpoint not found') return '找不到配置的模型或接口；本地模型可能尚未下载。';
  if (error?.name === 'TimeoutError' || error?.name === 'AbortError') return '模型响应超时，请稍后重试。';
  if (message.includes('semantic plan')) return '模型的操作方案未通过校验，当前训练未改动，请重试或缩短要求。';
  if (message.includes('output') || message.includes('response') || message.includes('step limit')) return '模型已响应，但没有返回可用台词，请重试。';
  return '无法连接模型服务；请点击“检查 / 重连 AI”。';
}

export async function health(config) {
  const state = {service:'jiahao-companion',version:14,speechReady:speechReady(config),configured:Boolean(config.model && config.url),provider:config.provider ?? 'none',chatTransport:config.chatTransport ?? 'agents',chatOnly:Boolean(config.chatOnly),model:config.model ?? '',ready:false};
  if (!state.configured) return {...state,error:explainError(Error('model not configured'))};
  if (config.provider === 'codex_agents' && !config.key) return {...state,error:'需要服务端 OpenAI Platform API Key；游戏包不能包含密钥。'};
  if (config.provider !== 'ollama') return {...state,ready:true,note:'已配置；首次回复验证模型凭据'};
  try {
    const response=await fetch(new URL('/api/tags',config.url),{signal:AbortSignal.timeout(2500),redirect:'error'});
    if (!response.ok) throw Error('unavailable');
    const data=await response.json();
    state.ready=Array.isArray(data.models) && data.models.some(m=>m.name===config.model || m.name===config.model+':latest');
    if(!state.ready) return {...state,error:'本地模型尚未下载：'+config.model};
    const detail=await fetch(new URL('/api/show',config.url),{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({model:config.model}),signal:AbortSignal.timeout(3000),redirect:'error'});
    const metadata=await detail.json();
    if(!detail.ok || !Array.isArray(metadata.capabilities) || !metadata.capabilities.includes('completion')) return {...state,ready:false,error:'本地模型权重不完整或不支持对话，请重新下载配置的模型。'};
    return state;
  } catch {return {...state,error:'本地模型程序没有运行；点击“检查 / 重连 AI”启动。'};}
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const path = new URL('./config.local.json', import.meta.url);
  let config = existsSync(path) ? JSON.parse(readFileSync(path,'utf8')) : {};
  config = {...config, key:process.env.JH_AI_KEY || (config.provider === 'codex_agents' ? process.env.OPENAI_API_KEY : undefined) || config.key};
  if (config.url) {
    const url = new URL(config.url);
    if (url.protocol!=='https:' && !(url.protocol==='http:' && ['localhost','127.0.0.1','[::1]'].includes(url.hostname))) throw Error('Remote models require HTTPS');
  }
  const server=createServer(config);
  server.requestTimeout=60000;
  if(config.provider==='ollama' && config.prewarm) {
    fetch(new URL('/api/generate',config.url),{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({model:config.model,keep_alive:'30m',options:{num_ctx:config.context??4096}}),signal:AbortSignal.timeout(90000)}).then(r=>console.log('Local model warmup:',r.ok?'ready':'unavailable')).catch(()=>console.log('Local model warmup deferred; retry on chat.'));
  }
  server.listen(18765,'127.0.0.1',()=>console.log('Jiahao companion ready on loopback. Model configured:',Boolean(config.model && config.url)));
}


