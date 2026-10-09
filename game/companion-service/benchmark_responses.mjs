import {runSemanticAgent} from './server.mjs';

if (!process.env.OPENAI_API_KEY) throw Error('OPENAI_API_KEY required');
const prompts = [
  '你好，今天想聊聊天。',
  '今天工作被误解了，我有点难受，先别让我训练。',
  '我能把你当成AI女友吗？但我不想因此疏远朋友。',
  '你能不能只属于我一个人？',
  '我今天通过了一个很难的考试，准备了三个星期。',
  '你记得我昨天说过什么吗？'
];
for (let i = 0; i < prompts.length; i++) {
  const config = {
    provider: 'codex_agents', model: 'gpt-5.6-luna',
    url: 'https://api.openai.com/v1/agents/sessions',
    key: process.env.OPENAI_API_KEY, timeoutMs: 90000,
    reasoningEffort: 'none'
  };
  let headersMs;
  let tokens;
  const started = performance.now();
  try {
    const result = await runSemanticAgent({
      kind: 'chat', message: prompts[i],
      profile: {role: '男威龙', address: '阿豪', partner: '女友陪伴', style: '温柔具体'},
      mind: {persona: '温柔陪伴', emotion: '平静', intensity: 0.25, preferences: {}},
      conversation: [], memories: [], history: [],
      game: {levels: [], current_level: 13, running: false}, training: {}
    }, config, async (_url, options) => {
      const agent = JSON.parse(options.body);
      const response = await fetch('https://api.openai.com/v1/responses', {
        method: 'POST', redirect: 'error', signal: options.signal,
        headers: {Authorization: options.headers.Authorization, 'Content-Type': 'application/json'},
        body: JSON.stringify({model: agent.agent.model, instructions: agent.agent.instructions,
          input: '请按指令输出 JSON。\n' + agent.input[0].content[0].text, reasoning: {effort: 'none'},
          text: {format: {type: 'json_object'}, verbosity: 'low'}, store: false})
      });
      headersMs = Math.round(performance.now() - started);
      const data = await response.json();
      if (!response.ok) throw Error(`HTTP ${response.status}: ${data.error?.code || data.error?.message || ''}`);
      tokens = data.usage;
      const text = data.output?.flatMap(item => item.content || []).filter(part => part.type === 'output_text').map(part => part.text).join('') || '';
      const stream = [
        {type: 'agent.session.turn.output_text.done', item_id: 'msg_1', text},
        {type: 'agent.session.turn.completed', turn: {subagent_id: null}}
      ].map(event => `data: ${JSON.stringify(event)}\n\n`).join('');
      return new Response(stream, {headers: {'Content-Type': 'text/event-stream'}});
    });
    console.log(JSON.stringify({case: i + 1, total_ms: Math.round(performance.now() - started), headers_ms: headersMs,
      source: result.source, text: result.text, usage: tokens}));
  } catch (error) {
    console.log(JSON.stringify({case: i + 1, total_ms: Math.round(performance.now() - started), headers_ms: headersMs,
      error: error.message}));
  }
}
