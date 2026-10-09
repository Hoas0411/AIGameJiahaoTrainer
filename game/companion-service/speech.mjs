import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {mkdtemp, writeFile, rm} from 'node:fs/promises';
import {existsSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';

const execute = promisify(execFile);
export function speechReady(config) {
  return Boolean(config.speechExecutable && config.speechModel && existsSync(config.speechExecutable) && existsSync(config.speechModel));
}
export function validateWav(b) {
  if (b.length < 8044 || b.length > 384044 || b.toString('ascii',0,4)!=='RIFF' || b.toString('ascii',8,12)!=='WAVE' || b.toString('ascii',12,16)!=='fmt ' || b.readUInt32LE(16)!==16 || b.readUInt16LE(20)!==1 || b.readUInt16LE(22)!==1 || b.readUInt32LE(24)!==16000 || b.readUInt32LE(28)!==32000 || b.readUInt16LE(32)!==2 || b.readUInt16LE(34)!==16 || b.toString('ascii',36,40)!=='data' || b.readUInt32LE(40)!==b.length-44 || b.readUInt32LE(4)!==b.length-8 || (b.length-44)%2) throw Error('需要 0.25–12 秒的 16kHz 单声道 PCM16 录音');
  let energy=0;
  for(let i=44;i<b.length;i+=2) energy+=(b.readInt16LE(i)/32768)**2;
  return Math.sqrt(energy/((b.length-44)/2));
}
export async function transcribe(b,config) {
  const rms=validateWav(b);
  if (rms<0.003) return {text:'',source:'local_speech',silent:true};
  if(!speechReady(config)) throw Error('本机语音模型尚未安装，请运行语音安装脚本');
  const directory=await mkdtemp(join(tmpdir(),'jiahao-speech-'));
  try {
    const path=join(directory,'utterance.wav');
    await writeFile(path,b);
    const {stdout}=await execute(config.speechExecutable,['-m',config.speechModel,'-f',path,'-l','zh','-t','4','-bs','1','-bo','1','-np','-nt','-nf'],{windowsHide:true,timeout:35000,maxBuffer:131072,encoding:'utf8'});
    const text=stdout.replace(/\[[^\]]*\]|\([^)]*\)|<\|[^|]*\|>/g,'').replace(/\s+/g,' ').trim().slice(0,1500);
    return {text,source:'local_speech'};
  } finally {
    await rm(directory,{recursive:true,force:true});
  }
}
