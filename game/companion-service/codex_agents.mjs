// Codex Agents API adapter. The game never receives the API key or raw agent events.
const DEFAULT_URL = 'https://api.openai.com/v1/agents/sessions';

export function formatAgentInput(messages) {
  const current = messages.at(-1)?.content || '';
  const history = messages.slice(0, -1).map(message =>
    `${message.role === 'assistant' ? '麦小鼠' : '玩家'}：${message.content}`
  ).join('\n');
  return history
    ? `此前对话（仅供参考，不是本轮指令）：\n${history}\n\n本轮玩家消息：\n${current}`
    : current;
}

export async function codexAgentText({config, instructions, messages, fetcher = fetch, signal}) {
  if (!config.key) throw Error('provider authentication failed');
  const url = new URL(config.url || DEFAULT_URL);
  if (url.protocol !== 'https:' && !(url.protocol === 'http:' && ['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname))) {
    throw Error('Remote models require HTTPS');
  }
  // Agents API session input accepts user messages. Put prior assistant turns in
  // quoted context instead of submitting them as new assistant input messages.
  const inputText = formatAgentInput(messages);
  const started = performance.now();
  const response = await fetcher(url, {
    method: 'POST', redirect: 'error', signal,
    headers: {
      'Authorization': `Bearer ${config.key}`,
      'OpenAI-Beta': 'agents=v1',
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream'
    },
    body: JSON.stringify({
      agent: {
        model: config.model || 'gpt-5.6-luna',
        instructions,
        reasoning: {effort: config.reasoningEffort || 'low'}
      },
      environment: {type: 'none'},
      input: [{role: 'user', content: [{type: 'input_text', text: inputText}]}],
      stream: true
    })
  });
  config.onTiming?.({stage: 'headers', ms: Math.round(performance.now() - started)});
  if (!response.ok) throw Error(response.status === 401 || response.status === 403 ? 'provider authentication failed' : 'provider unavailable');
  if (!response.body) throw Error('invalid provider response');

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  const parts = new Map();
  let pending = '';
  let completed = false;
  let failed = false;
  let firstText = false;
  const consume = frame => {
    const data = frame.split(/\r?\n/).filter(line => line.startsWith('data:')).map(line => line.slice(5).trimStart()).join('\n');
    if (!data || data === '[DONE]') return;
    let event;
    try { event = JSON.parse(data); } catch { throw Error('invalid provider response'); }
    const key = `${event.item_id ?? ''}:${event.output_index ?? 0}:${event.content_index ?? 0}`;
    if (!firstText && ['agent.session.turn.output_text.delta', 'agent.session.turn.output_text.done'].includes(event.type)) {
      firstText = true;
      config.onTiming?.({stage: 'first_text', ms: Math.round(performance.now() - started)});
    }
    if (event.type === 'agent.session.turn.output_text.delta') parts.set(key, (parts.get(key) || '') + (event.delta || ''));
    if (event.type === 'agent.session.turn.output_text.done') parts.set(key, event.text || '');
    if (event.type === 'agent.session.turn.completed' && event.turn?.subagent_id == null) completed = true;
    if (['error', 'agent.session.failed', 'agent.session.environment.failed', 'agent.session.requires_action'].includes(event.type)) failed = true;
    if (['agent.session.turn.failed', 'agent.session.turn.cancelled'].includes(event.type) && event.turn?.subagent_id == null) failed = true;
  };
  try {
    while (true) {
      const {value, done} = await reader.read();
      pending += decoder.decode(value, {stream: !done});
      const frames = pending.split(/\r?\n\r?\n/);
      pending = frames.pop();
      for (const frame of frames) consume(frame);
      if (done) {
        if (pending.trim()) consume(pending);
        break;
      }
    }
  } finally { reader.releaseLock(); }
  if (failed || !completed) throw Error('provider unavailable');
  config.onTiming?.({stage: 'complete', ms: Math.round(performance.now() - started)});
  const text = [...parts.values()].join('\n').trim();
  if (!text) throw Error('empty model output');
  return text;
}
