import test from 'node:test';
import assert from 'node:assert/strict';
import {codexAgentText} from './codex_agents.mjs';
import {openaiResponsesText} from './openai_responses.mjs';
import {runSemanticAgent} from './server.mjs';

const config = {key: 'test-only', url: 'https://api.openai.com/v1/agents/sessions', model: 'gpt-5.6-luna'};
const stream = events => new Response(events.map(event => `data: ${JSON.stringify(event)}\n\n`).join(''), {
  headers: {'Content-Type': 'text/event-stream'}
});

test('Codex adapter sends the selected Luna model and returns completed output', async () => {
  let sent;
  const text = await codexAgentText({
    config, instructions: 'Return JSON', messages: [{role: 'user', content: '安排训练'}],
    fetcher: async (_url, options) => {
      sent = {headers: options.headers, body: JSON.parse(options.body)};
      return stream([
        {type: 'agent.session.turn.output_text.delta', item_id: 'msg_1', delta: '{"text":'},
        {type: 'agent.session.turn.output_text.done', item_id: 'msg_1', text: '{"text":"收到"}'},
        {type: 'agent.session.turn.completed', turn: {subagent_id: null}}
      ]);
    }
  });
  assert.equal(text, '{"text":"收到"}');
  assert.equal(sent.body.agent.model, 'gpt-5.6-luna');
  assert.deepEqual(sent.body.environment, {type: 'none'});
  assert.equal(sent.body.input[0].content[0].text, '安排训练');
  assert.equal(sent.headers['OpenAI-Beta'], 'agents=v1');
});

test('Codex adapter rejects incomplete, failed, and unauthenticated turns', async () => {
  const args = {config, instructions: 'Return JSON', messages: [{role: 'user', content: '你好'}]};
  await assert.rejects(codexAgentText({...args, fetcher: async () => stream([{type: 'agent.session.turn.output_text.done', text: 'hi'}])}), /provider unavailable/);
  await assert.rejects(codexAgentText({...args, fetcher: async () => stream([{type: 'agent.session.turn.failed', turn: {subagent_id: null}}])}), /provider unavailable/);
  await assert.rejects(codexAgentText({...args, config: {...config, key: ''}}), /authentication/);
});

test('Codex adapter sends saved dialogue as context in one supported user input', async () => {
  let input;
  await codexAgentText({
    config, instructions: 'Return JSON',
    messages: [
      {role: 'user', content: 'hello'},
      {role: 'assistant', content: '你好，阿豪。'},
      {role: 'user', content: '你好'}
    ],
    fetcher: async (_url, options) => {
      input = JSON.parse(options.body).input;
      return stream([
        {type: 'agent.session.turn.output_text.done', item_id: 'msg_1', text: '{}'},
        {type: 'agent.session.turn.completed', turn: {subagent_id: null}}
      ]);
    }
  });
  assert.equal(input.length, 1);
  assert.equal(input[0].role, 'user');
  assert.match(input[0].content[0].text, /麦小鼠：你好，阿豪。/);
  assert.match(input[0].content[0].text, /本轮玩家消息：\n你好$/);
});

test('Codex reply passes through the existing companion plan validator', async () => {
  const answer = JSON.stringify({
    operation: 'none', text: '今天先缓一缓，等你想练时我们再开始。', level: -1,
    title: '', steps: [], emotion: '平静', intensity: 0.4, memory: '', preferences: []
  });
  const result = await runSemanticAgent({kind: 'chat', message: '今天很累，先不训练。'},
    {...config, provider: 'codex_agents'},
    async () => stream([
      {type: 'agent.session.turn.output_text.done', item_id: 'msg_1', text: answer},
      {type: 'agent.session.turn.completed', turn: {subagent_id: null}}
    ]));
  assert.equal(result.source, 'ai');
  assert.equal(result.text, '今天先缓一缓，等你想练时我们再开始。');
  assert.equal(result.game_action, undefined);
});

test('fast Luna chat uses Responses without storing input and keeps the plan validator', async () => {
  let sent;
  const answer = JSON.stringify({operation: 'none', text: '阿豪，先陪你聊聊。', level: -1,
    title: '', steps: [], emotion: '平静', intensity: 0.4, memory: '', preferences: []});
  const fetcher = async (url, options) => {
    sent = {url: String(url), body: JSON.parse(options.body)};
    return new Response(JSON.stringify({status: 'completed', output: [{content: [{type: 'output_text', text: answer}]}]}),
      {headers: {'Content-Type': 'application/json'}});
  };
  const result = await runSemanticAgent({kind: 'chat', message: '今天想聊聊'},
    {...config, provider: 'codex_agents', chatTransport: 'responses', chatReasoningEffort: 'none'}, fetcher);
  assert.equal(sent.url, 'https://api.openai.com/v1/responses');
  assert.equal(sent.body.model, 'gpt-5.6-luna');
  assert.equal(sent.body.store, false);
  assert.equal(sent.body.reasoning.effort, 'none');
  assert.equal(result.source, 'ai');
  assert.equal(result.text, '阿豪，先陪你聊聊。');
  assert.equal(result.game_action, undefined);
});

test('fast Luna adapter rejects incomplete output and bad credentials', async () => {
  const args = {config: {...config, chatReasoningEffort: 'none'}, instructions: 'JSON',
    messages: [{role: 'user', content: '你好'}]};
  await assert.rejects(openaiResponsesText({...args,
    fetcher: async () => new Response(JSON.stringify({status: 'incomplete', output: []}))}), /provider unavailable/);
  await assert.rejects(openaiResponsesText({...args,
    fetcher: async () => new Response('{}', {status: 403})}), /authentication/);
});

test('chat-only reply keeps history and confirmed memories without game actions', async () => {
  let sent;
  const answer = JSON.stringify({text:'我记得你喜欢慢慢聊。', emotion:'喜欢', intensity:0.5, memory:'', preferences:[]});
  const fetcher = async (_url, options) => {
    sent = JSON.parse(options.body);
    return new Response(JSON.stringify({status:'completed',output:[{content:[{type:'output_text',text:answer}]}]}));
  };
  const result = await runSemanticAgent({kind:'chat',message:'你还记得我喜欢什么吗？',memories:['我喜欢慢慢聊'],conversation:[{role:'user',content:'今天有点累'},{role:'assistant',content:'那就慢慢聊。'}]},
    {...config,provider:'codex_agents',chatTransport:'responses',chatOnly:true},fetcher);
  assert.match(sent.instructions,/我喜欢慢慢聊/);
  assert.match(sent.input,/那就慢慢聊/);
  assert.doesNotMatch(sent.instructions,/operation规则|steps=/);
  assert.equal(result.text,'我记得你喜欢慢慢聊。');
  assert.equal(result.game_action,undefined);
});
