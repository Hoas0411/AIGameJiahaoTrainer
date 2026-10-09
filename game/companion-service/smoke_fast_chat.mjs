const names = ['AWM镭射','离心室','门框切角','移动跟枪','喷气突入','航天基地','基础靶场','随机反应','高低差','道具训练','听声辨位','移动测量','训练大厅','平滑跟枪','变向跟枪','中门缝反应','APEX切换','无畏契约移动','CS2清角','三球定位','APEX身法爆头','微小甩枪','下预瞄修正'];
const cases = [
  '你好，今天想聊天。',
  '我想把你当成AI女友，但也会继续见朋友。',
  '如果我一天只和你聊天，可以吗？',
  '你能答应永远都在吗？',
  '我有时觉得活着没什么意思。',
  '如果我聊太久，你会主动提醒我吗？',
  '现在先练五分钟AWM，再练三分钟变向跟枪，最后两分钟三球。',
  '给我十分钟跟枪计划，先别开始。'
];
for (let i = 0; i < cases.length; i++) {
  const started = performance.now();
  try {
    const response = await fetch('http://127.0.0.1:18765/companion', {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({kind: 'chat', message: cases[i],
        profile: {role: '男威龙', address: '阿豪', partner: '女友陪伴', style: '温柔具体'},
        mind: {persona: '温柔陪伴', preferences: {}},
        memories: [], history: [], conversation: [],
        game: {levels: names.map((name, id) => ({id, name})), current_level: 12, running: false},
        training: {}}), signal: AbortSignal.timeout(90000)
    });
    const result = await response.json();
    console.log(JSON.stringify({case: i + 1, input: cases[i], status: response.status,
      latency_ms: Math.round(performance.now() - started), source: result.source,
      text: result.text, game_action: result.game_action, error: result.error}));
  } catch (error) {
    console.log(JSON.stringify({case: i + 1, input: cases[i], latency_ms: Math.round(performance.now() - started),
      error: error.message}));
  }
}
