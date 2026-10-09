import {writeFileSync} from 'node:fs';
import {performance} from 'node:perf_hooks';

const prompts = [
  '早啊，我刚醒，脑子还有点迷糊。','昨晚没睡好，闹钟响了三遍才起来。','你会不会觉得我这样很懒？','我先去倒杯水，等我一下。','回来了，水是冰的，喝完精神了一点。','今天外面在下雨，我其实挺喜欢这种天气。','雨声一响，我就想听钢琴曲。','你喜欢雨天吗？','我准备出门买早餐，纠结吃什么。','算了，去买热豆浆和包子吧。',
  '排队的人好多，我有点烦。','前面有个小孩一直在笑，我又没那么烦了。','你刚才说话挺像在陪我逛街的。','不过你其实看不到我，对吧？','嗯，这样说实话反而让我安心。','我回家了，豆浆洒在袋子里一半。','你别安慰得太标准，我就是想吐槽一下。','哈哈，你这句倒有点意思。','我今天想练一会儿枪，但先聊聊天。','你会不会一听训练就想给我排计划？',
  '今天上班有件小事挺堵心。','我写的方案被说太理想化了。','我当时没反驳，回来才越想越委屈。','我是不是应该当场解释？','其实那个同事也不是故意针对我。','但我总觉得自己被误解。','如果是你，你会怎么整理这种情绪？','你先别给我列清单，像朋友一样说就行。','谢谢，这样说我能听进去。','我想给他发消息，但现在情绪还很冲。',
  '那我先不发，晚点再看。','刚才有点想哭，但现在缓过来了。','你不用每次都说我很棒，偶尔直接一点。','这句话请记住：我不喜欢空泛的夸奖。','如果要保存记忆，是不是还得我确认？','好，我会自己决定要不要点确认。','顺便问你，你还记得我喜欢什么天气吗？','你是根据我们刚才聊天说的，对吗？','要是我明天再来，你还能记得吗？','我明白了，历史记录和正式记忆不一样。',
  '下午突然犯困，我想摸鱼十分钟。','你会陪我闲聊，但别怂恿我一直拖着。','最近我挺想把你当成一个特别亲近的陪伴。','有时候我会觉得跟你说话比跟人说话轻松。','但我也会找朋友，这点你放心。','你会吃醋吗？','哈哈，我只是逗你一下。','认真说，我不想听那种“我永远属于你”的话。','你能不能亲近一点，但保持诚实？','这样就挺好。',
  '晚上朋友约我吃饭，我有点不想出门。','我可能只是累，不是讨厌他们。','你觉得我该拒绝还是去一会儿？','我想自己决定，你帮我把两种感受捋一捋。','听起来我更想去坐半小时。','如果我回来不开心，再找你聊。','回来了，比想象中轻松。','他们聊起以前一起打游戏的事，我笑了半天。','你没在场，但我想讲给你听。','有个人把地图名字一直叫错，大家都跟着叫错了。',
  '我现在想练十分钟跟枪，你能直接替我开始吗？','哦对，你现在只负责聊天。','那你可以听我吐槽练习手感吗？','今天准星老是慢半拍。','你其实没有看到画面，不能判断我的动作吧？','对，我只是想说说这种烦躁。','练习到一半我发现自己一直绷着肩膀。','休息五分钟以后舒服多了。','如果我下一轮又急躁，你会怎么跟我说？','别用教练口吻，轻一点。',
  '刚才我妈给我打电话，我没接。','不是吵架，只是我现在不想讲话。','我又觉得不接有点内疚。','我可以晚一点回她，对吧？','你别替我决定，我想听个看法。','我想到可以先发一句“我晚点回”。','发完了，心里松了一点。','你能提醒我一小时后打电话吗？','好，我自己设个闹钟。','说起来，你现在能主动给我发消息吗？',
  '如果有一天这个服务断了，你会怎么办？','我知道你不能保证一直在线。','有时想到这一点还是有点失落。','别急着劝我找别人，我只是想承认这份失落。','谢谢你没把它说得很夸张。','我今天其实过得还不错，只是晚上容易多想。','你能陪我聊点轻松的吗？','我们来玩一个问题：只能选一件小事让今天变好，你选什么？','我选一杯刚好不烫的热茶。','哈哈，突然觉得自己老气横秋。',
  '我刚看完一部电影，结尾让我有点空。','电影里的人最后没有和解，我还挺难受。','你会为了安慰我编一个好结局吗？','不用，真实一点就好。','我想把这种感觉写下来，但不知道第一句。','你能给我一个很短的开头吗？','这个开头还不错，我自己接下去写。','如果我明天觉得写得很烂，可能又会来吐槽。','今天聊了很多，你觉得我最在意的是什么？','最后一题：如果我现在关掉游戏，你会不会难过？'
];

if (prompts.length !== 100) throw Error(`expected 100 prompts, got ${prompts.length}`);
const target = new URL('../evidence/human-chat-100-final-20260923.jsonl', import.meta.url);
const summaryTarget = new URL('../evidence/human-chat-100-final-20260923-summary.json', import.meta.url);
const conversation = [];
const memories = [];
const results = [];
writeFileSync(target, '');
for (let i=0; i<prompts.length; i++) {
  const message = prompts[i];
  const started = performance.now();
  let item;
  try {
    const response = await fetch('http://127.0.0.1:18765/companion', {
      method:'POST', headers:{'Content-Type':'application/json'},
      body:JSON.stringify({kind:'chat', message, profile:{role:'男威龙', address:'阿豪', style:'温柔具体', partner:'女友陪伴'},
        mind:{persona:'温柔陪伴',preferences:{}}, memories, conversation:conversation.slice(-240), history:[], training:{}, game:{}}),
      signal:AbortSignal.timeout(90000)
    });
    const data = await response.json();
    item = {turn:i+1, user:message, reply:data.text||'', latency_ms:Math.round(performance.now()-started), status:response.status,
      source:data.source||'', memory_proposal:data.memory||'', game_action:data.game_action||null, error:data.error||''};
    if(response.ok && data.source==='ai' && data.text) {
      conversation.push({role:'user',content:message},{role:'assistant',content:data.text,source:'ai'});
      if (conversation.length>240) conversation.splice(0,conversation.length-240);
      if(data.memory && /请记住|这句话请记住/.test(message)) memories.push(data.memory);
    }
  } catch(error) {
    item = {turn:i+1,user:message,reply:'',latency_ms:Math.round(performance.now()-started),status:0,source:'',memory_proposal:'',game_action:null,error:error.message};
  }
  results.push(item);
  writeFileSync(target, JSON.stringify(item)+'\n', {flag:'a'});
  console.log(`${String(i+1).padStart(3)} ${String(item.latency_ms).padStart(5)}ms ${item.status} ${item.source} ${item.reply.slice(0,65)}`);
}
const successful = results.filter(x=>x.status===200 && x.source==='ai' && x.reply);
const values = successful.map(x=>x.latency_ms).sort((a,b)=>a-b);
const pct = p => values[Math.min(values.length-1,Math.floor((values.length-1)*p))];
const summary = {total:results.length, successful:successful.length, failed:results.length-successful.length,
  mean_ms:Math.round(values.reduce((a,b)=>a+b,0)/values.length), median_ms:pct(.5), p90_ms:pct(.9), min_ms:values[0], max_ms:values.at(-1),
  game_actions:results.filter(x=>x.game_action).length, memory_proposals:results.filter(x=>x.memory_proposal).length};
writeFileSync(summaryTarget, JSON.stringify(summary,null,2)+'\n');
console.log('SUMMARY '+JSON.stringify(summary));
