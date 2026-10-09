// Evidence is a quote from the current player message, never a model-generated permission.
export function instructionEvidence(context, evidence) {
  const text=context.message.trim();
  if(evidence!==undefined && (typeof evidence!=='string' || evidence.trim().length<2 || !text.includes(evidence.trim())))return '';
  const candidate=text; // Validate enclosing clauses so a quote cannot strip a negation.
  const clauses=candidate.split(/[，,。；;！!\n]|但是|而是|不过/).map(s=>s.trim()).filter(Boolean);
  return clauses.filter(s=>!/(?:不要|不用|别|不想|不需要|暂不|先不|如果|假如|假设|怎么|如何|为什么)/.test(s) && /去|带|帮|请|练|安排|开始|切|换|进|计划|准备|推荐|暂停|停止|取消|继续|下一|接着|接下来|先/.test(s)).join('，');
}
export function routeSteps(args, context) {
  if(!Array.isArray(args?.steps) || args.steps.length<1 || args.steps.length>8)return null;
  let total=0;const steps=[];
  for(const step of args.steps){
    if(!Number.isInteger(step?.level)||step.level===12||!context.game.levels.some(l=>l.id===step.level)||!Number.isInteger(step.seconds)||step.seconds<30||step.seconds>600)return null;
    if(step.weapon!==undefined && !['awm','rifle'].includes(step.weapon))return null;
    total+=step.seconds;
    steps.push({level:step.level,seconds:step.seconds,weapon:step.weapon??(step.level===0?'awm':'rifle'),goal:typeof step.goal==='string'?step.goal.slice(0,100):'按自己的节奏练习'});
  }
  return total<=3600?steps:null;
}

export function excludedLevel(context, level) {
 const names={0:['awm','aw','镭射','雷射'],3:['移动跟枪'],13:['平滑跟枪'],14:['变向跟枪'],15:['中门缝'],19:['三球','gridshot']};
 const aliases=[context.game.levels.find(l=>l.id===level)?.name,...(names[level]??[])].filter(Boolean);
 return context.message.toLowerCase().split(/[，,。；;！!\n]|但是|而是|不过/).some(clause=>/(不要|不用|不想|别|排除|不练)/.test(clause)&&aliases.some(name=>clause.includes(name.toLowerCase())));
}

export function durationConstraint(message, steps) {
 const number=s=>{if(/^\d+(?:\.\d+)?$/.test(s))return Number(s);const digits={零:0,一:1,二:2,两:2,三:3,四:4,五:5,六:6,七:7,八:8,九:9};if(s==='半')return .5;if(s.includes('十')){const [a,b]=s.split('十');return (digits[a]??1)*10+(digits[b]??0);}return digits[s]??NaN;};
 const durations=[...message.matchAll(/(\d+(?:\.\d+)?|[一二两三四五六七八九十半]+)\s*(分钟|秒)/g)].map(m=>number(m[1])*(m[2]==='分钟'?60:1));
 if(durations.some(n=>!Number.isFinite(n)))return '';
 if(durations.length===1 && /计划|路线|安排/.test(message) && !/每|各|至少|最多|大约|左右/.test(message) && steps.reduce((n,s)=>n+s.seconds,0)!==durations[0])return 'route total seconds must equal requested '+durations[0];
 if(durations.length>1 && /先|再|然后|最后|分别|依次/.test(message) && (steps.length!==durations.length || steps.some((s,i)=>s.seconds!==durations[i])))return 'stage seconds must keep requested order: '+durations.join(',');
 return '';
}
// A suggested plan has freely allocated stage lengths when the player specifies
// only a total. Fit that allocation deterministically instead of asking the LLM
// to redo arithmetic. Explicit per-stage timings are never rewritten.
export function fitSuggestedDuration(message,steps) {
 if([...message.matchAll(/(\d+(?:\.\d+)?|[一二两三四五六七八九十半]+)\s*(分钟|秒)/g)].length!==1 || !/计划|路线|安排/.test(message) || /每|各|至少|最多|大约|左右|先练|然后|再练/.test(message))return steps;
 const unit=message.match(/(\d+(?:\.\d+)?|[一二两三四五六七八九十半]+)\s*(分钟|秒)/);if(!unit)return steps;
 const digits={一:1,二:2,两:2,三:3,四:4,五:5,六:6,七:7,八:8,九:9};let value=Number(unit[1]);
 if(!Number.isFinite(value)){if(unit[1]==='半')value=.5;else if(unit[1].includes('十')){const [a,b]=unit[1].split('十');value=(digits[a]??1)*10+(digits[b]??0);}else value=digits[unit[1]];}
 const total=value*(unit[2]==='分钟'?60:1),sum=steps.reduce((n,s)=>n+s.seconds,0);
 if(!Number.isInteger(total)||total===sum||total<steps.length*30||total>Math.min(3600,steps.length*600))return steps;
 const fitted=steps.map(s=>({...s,seconds:Math.max(30,Math.min(600,Math.floor(s.seconds*total/sum)))}));
 let difference=total-fitted.reduce((n,s)=>n+s.seconds,0);
 while(difference!==0)for(const step of fitted){if(difference>0 && step.seconds<600){step.seconds++;difference--;}else if(difference<0 && step.seconds>30){step.seconds--;difference++;}if(!difference)break;}
 return fitted;
}