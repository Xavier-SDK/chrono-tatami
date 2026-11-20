/* Chrono Tatami : playlist (IndexedDB), lecteur avec baisse de volume, commandes Apple Watch (Media Session) */
(function(){
'use strict';
const DBN='chrono-tatami',ST='pistes',KORD='ct.playlist';

/* ---------- stockage des morceaux ---------- */
let dbp=null;
function db(){
  if(!dbp)dbp=new Promise((ok,ko)=>{const r=indexedDB.open(DBN,1);
    r.onupgradeneeded=()=>{if(!r.result.objectStoreNames.contains(ST))r.result.createObjectStore(ST,{keyPath:'id'});};
    r.onsuccess=()=>ok(r.result);r.onerror=()=>ko(r.error);});
  return dbp;
}
function req(mode,fn){return db().then(d=>new Promise((ok,ko)=>{const t=d.transaction(ST,mode);const r=fn(t.objectStore(ST));
  t.oncomplete=()=>ok(r?r.result:undefined);t.onerror=()=>ko(t.error);t.onabort=()=>ko(t.error);}));}
const getOrd=()=>{try{return JSON.parse(localStorage.getItem(KORD)||'[]');}catch(e){return [];}};
const setOrd=a=>{try{localStorage.setItem(KORD,JSON.stringify(a));}catch(e){}};
let META=[];                                   /* [{id,nom,artiste,duree,taille}] dans l'ordre de la playlist */
async function refresh(){
  let all=[];try{all=await req('readonly',s=>s.getAll());}catch(e){all=[];}
  const by=new Map(all.map(r=>[r.id,r]));const ord=getOrd().filter(id=>by.has(id));
  all.forEach(r=>{if(!ord.includes(r.id))ord.push(r.id);});setOrd(ord);
  META=ord.map(id=>{const r=by.get(id);return {id,nom:r.nom,artiste:r.artiste,duree:r.duree,taille:r.taille};});
  return META;
}
function duree(file){return new Promise(ok=>{const a=new Audio();const u=URL.createObjectURL(file);let done=false;
  const fin=d=>{if(done)return;done=true;URL.revokeObjectURL(u);ok(isFinite(d)?d:0);};
  a.preload='metadata';a.onloadedmetadata=()=>fin(a.duration);a.onerror=()=>fin(0);setTimeout(()=>fin(0),4000);a.src=u;});}
async function add(files){
  const ord=getOrd();let n=0;
  for(const f of files){if(!/^audio\//.test(f.type)&&!/\.(mp3|m4a|aac|wav|ogg)$/i.test(f.name))continue;
    const base=f.name.replace(/\.[^.]+$/,'');const m=base.match(/^(.*?)\s+-\s+(.*)$/);
    const rec={id:'p'+Date.now().toString(36)+Math.random().toString(36).slice(2,7),nom:(m?m[2]:base).trim(),artiste:m?m[1].trim():'',
      duree:await duree(f),taille:f.size,type:f.type||'audio/mpeg',blob:f};
    await req('readwrite',s=>s.put(rec));ord.push(rec.id);n++;}
  setOrd(ord);await refresh();order=[];return n;
}
async function remove(id){await req('readwrite',s=>s.delete(id));setOrd(getOrd().filter(x=>x!==id));await refresh();order=[];}
async function usage(){try{const e=await navigator.storage.estimate();return e.usage||0;}catch(e){return META.reduce((a,m)=>a+(m.taille||0),0);}}

/* ---------- lecteur ---------- */
let A=null,G=null,AC=null,mode='off',gainT=-1,url=null,cur=null,order=[],pos=0,saved=null,busy=false,silUrl=null,opts={alea:true};
function silence(){
  if(silUrl)return silUrl;
  const sr=8000,n=sr*10,b=new ArrayBuffer(44+n),v=new DataView(b),w=(o,s)=>{for(let i=0;i<s.length;i++)v.setUint8(o+i,s.charCodeAt(i));};
  w(0,'RIFF');v.setUint32(4,36+n,true);w(8,'WAVE');w(12,'fmt ');v.setUint32(16,16,true);v.setUint16(20,1,true);v.setUint16(22,1,true);
  v.setUint32(24,sr,true);v.setUint32(28,sr,true);v.setUint16(32,1,true);v.setUint16(34,8,true);w(36,'data');v.setUint32(40,n,true);
  for(let i=0;i<n;i++)v.setUint8(44+i,128);
  silUrl=URL.createObjectURL(new Blob([b],{type:'audio/wav'}));return silUrl;
}
function setup(ac){
  if(A)return;A=new Audio();A.preload='auto';A.setAttribute('playsinline','');A.crossOrigin='anonymous';
  if(ac){try{const src=ac.createMediaElementSource(A);G=ac.createGain();G.gain.value=0;src.connect(G).connect(ac.destination);AC=ac;}catch(e){G=null;}}
  A.addEventListener('ended',()=>{if(mode==='music')next();});
}
/* À appeler dans un geste de l'utilisateur (Go, Reprendre) : iOS n'autorise la lecture qu'ensuite. */
function unlock(ac){
  setup(ac);if(mode!=='off'||!A)return;
  try{A.src=silence();A.loop=true;const p=A.play();if(p)p.then(()=>{if(mode==='off')A.pause();}).catch(()=>{});}catch(e){}
}
function gainTo(v,t){
  if(!A)return;v=Math.max(0,Math.min(1,v));if(Math.abs(v-gainT)<.005)return;gainT=v;
  if(G&&AC){const now=AC.currentTime;try{G.gain.cancelScheduledValues(now);G.gain.setValueAtTime(G.gain.value,now);G.gain.linearRampToValueAtTime(v,now+(t==null?.5:t));}catch(e){G.gain.value=v;}}
  else A.volume=v;
}
function makeOrder(){order=META.map(m=>m.id);if(opts.alea){for(let i=order.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[order[i],order[j]]=[order[j],order[i]];}}pos=0;}
async function load(at){
  if(!META.length)return false;if(!order.length||order.some(id=>!META.find(m=>m.id===id)))makeOrder();
  pos=((pos%order.length)+order.length)%order.length;
  let rec=null;try{rec=await req('readonly',s=>s.get(order[pos]));}catch(e){}
  if(!rec)return false;
  if(url)URL.revokeObjectURL(url);url=URL.createObjectURL(rec.blob);cur=rec;A.loop=false;A.src=url;
  if(at>0)A.addEventListener('loadedmetadata',()=>{try{A.currentTime=at;}catch(e){}},{once:true});
  return true;
}
async function next(){if(!A||!META.length)return;pos++;if(pos>=order.length){makeOrder();}saved=null;
  if(mode==='music'){busy=true;if(await load(0)){gainT=-1;try{await A.play();}catch(e){}}busy=false;}else saved={pos,t:0};}
/* want : 'music' | 'silence' | 'off' ; playing : chrono en marche ; level : volume visé 0..1 */
async function sync(want,playing,level){
  if(!A||busy)return;
  if(want==='music'&&!META.length)want='silence';
  if(!playing){if(!A.paused){gainTo(0,.15);setTimeout(()=>{if(!lastPlaying)A.pause();},170);}
    lastPlaying=false;setPlayback('paused');return;}
  lastPlaying=true;
  if(want!==mode){
    busy=true;
    if(mode==='music'){saved={pos,t:A.currentTime||0};gainTo(0,.6);await wait(650);}
    mode=want;gainT=-1;
    if(want==='music'){const s=saved||{pos,t:0};pos=s.pos;if(!(await load(s.t))){mode='silence';}}
    if(mode==='silence'){A.src=silence();A.loop=true;cur=null;gainTo(0,0);}
    if(mode==='off'){A.pause();gainTo(0,0);busy=false;setPlayback('none');return;}
    try{await A.play();}catch(e){}
    busy=false;
  }
  else if(A.paused&&mode!=='off'){try{await A.play();}catch(e){}}
  if(mode==='music')gainTo(level);
  if(mode!=='off')setPlayback('playing');
}
let lastPlaying=false;
const wait=ms=>new Promise(r=>setTimeout(r,ms));
function stop(){if(!A)return;saved=null;gainTo(0,.8);setTimeout(()=>{A.pause();mode='off';setPlayback('none');},850);}

/* ---------- Apple Watch et écran verrouillé : Media Session ---------- */
const MS='mediaSession' in navigator?navigator.mediaSession:null;
let lastMeta='',lastPosKey='';
function setPlayback(st){if(MS)try{MS.playbackState=st;}catch(e){}}
function session(info){
  if(!MS)return;
  const k=info.title+'|'+info.artist+'|'+info.album;
  if(k!==lastMeta){lastMeta=k;try{MS.metadata=new MediaMetadata({title:info.title,artist:info.artist,album:info.album,
    artwork:[{src:'icons/icon-512.png',sizes:'512x512',type:'image/png'},{src:'icons/icon-192.png',sizes:'192x192',type:'image/png'}]});}catch(e){}}
  if(info.duration>0&&MS.setPositionState){const pk=[Math.round(info.duration),Math.round(info.position),info.rate].join('|');
    if(pk!==lastPosKey){lastPosKey=pk;try{MS.setPositionState({duration:info.duration,position:Math.min(info.duration,Math.max(0,info.position)),playbackRate:info.rate||1});}catch(e){}}}
}
function handlers(h){if(!MS)return;
  const set=(a,f)=>{try{MS.setActionHandler(a,f||null);}catch(e){}};
  set('play',h.play);set('pause',h.pause);set('previoustrack',h.prev);set('nexttrack',h.next);
  set('seekbackward',null);set('seekforward',null);set('seekto',null);}
function clearSession(){if(!MS)return;lastMeta='';lastPosKey='';try{MS.metadata=null;}catch(e){}setPlayback('none');}

window.Musique={refresh,add,remove,usage,unlock,sync,next,stop,session,handlers,clearSession,
  get list(){return META;},count:()=>META.length,get current(){return mode==='music'&&cur?{nom:cur.nom,artiste:cur.artiste}:null;},
  get mode(){return mode;},set alea(v){if(opts.alea!==!!v){opts.alea=!!v;order=[];}}};
refresh();
})();
