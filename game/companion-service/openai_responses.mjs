import {formatAgentInput} from './codex_agents.mjs';

export async function openaiResponsesText({config, instructions, messages, fetcher = fetch, signal}) {
  if (!config.key) throw Error('provider authentication failed');
  const url = new URL(config.responsesUrl || 'https://api.openai.com/v1/responses');
  if (url.protocol !== 'https:' && !(url.protocol === 'http:' && ['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname))) {
    throw Error('Remote models require HTTPS');
  }
  const response = await fetcher(url, {
    method: 'POST', redirect: 'error', signal,
    headers: {
      Authorization: `Bearer ${config.key}`,
      'Content-Type': 'application/json',
      Accept: 'application/json'
    },
    body: JSON.stringify({
      model: config.model || 'gpt-5.6-luna',
      instructions,
      input: '请按指令输出 JSON。\n' + formatAgentInput(messages),
      reasoning: {effort: config.chatReasoningEffort || 'none'},
      text: {format: {type: 'json_object'}, verbosity: 'low'},
      max_output_tokens: config.chatMaxOutputTokens || 1100,
      store: false
    })
  });
  if (!response.ok) throw Error(response.status === 401 || response.status === 403 ? 'provider authentication failed' : 'provider unavailable');
  const data = await response.json();
  if (data.status !== 'completed') throw Error('provider unavailable');
  const text = data.output?.flatMap(item => item.content || [])
    .filter(part => part.type === 'output_text' && typeof part.text === 'string')
    .map(part => part.text).join('\n').trim();
  if (!text) throw Error('empty model output');
  return text;
}
