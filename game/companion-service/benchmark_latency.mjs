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
  for (const effort of i % 2 ? ['none', 'low'] : ['low', 'none']) {
    const timing = {};
    const config = {
      provider: 'codex_agents', model: 'gpt-5.6-luna',
      url: 'https://api.openai.com/v1/agents/sessions',
      key: process.env.OPENAI_API_KEY, timeoutMs: 90000,
      reasoningEffort: effort,
      onTiming: point => { timing[point.stage] = point.ms; }
    };
    const started = performance.now();
    try {
      const result = await runSemanticAgent({
        kind: 'chat', message: prompts[i],
        profile: {role: '男威龙', address: '阿豪', partner: '女友陪伴', style: '温柔具体'},
        mind: {persona: '温柔陪伴', emotion: '平静', intensity: 0.25, preferences: {}},
        conversation: [], memories: [], history: [],
        game: {levels: [], current_level: 13, running: false}, training: {}
      }, config);
      console.log(JSON.stringify({case: i + 1, effort, total_ms: Math.round(performance.now() - started), ...timing,
        source: result.source, text: result.text}));
    } catch (error) {
      console.log(JSON.stringify({case: i + 1, effort, total_ms: Math.round(performance.now() - started), ...timing,
        error: error.message}));
    }
  }
}
