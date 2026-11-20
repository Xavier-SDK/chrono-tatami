/* Chrono Tatami — app installable (PWA) */
(function(){
'use strict';
const VERSION='1.0 · 20/11/2026';
const COL={ouverture:'#F2EFE6',echauffement:'#FF7A1A',techniques:'#C6FF1A',pratique:'#FF3B30',calme:'#3DB8FF'};
const SECN={ouverture:'Salut',echauffement:'Échauffement',techniques:'Techniques',pratique:'Mise en pratique',calme:'Retour au calme'};
const ICO={travail:'<path d="M13 2 4 14h7l-1 8 9-12h-7z"/>',repos:'<path d="M8 5v14M16 5v14"/>',consigne:'<path d="M3 10v4h4l7 5V5L7 10z"/><path d="M18 9a4 4 0 0 1 0 6"/>'};
const MODE={travail:'Travail',repos:'Récup',consigne:'Démo'};
const TYPE={travail:'Travail',repos:'Récup',consigne:'Démo'};
const JOURS=['Dim.','Lun.','Mar.','Mer.','Jeu.','Ven.','Sam.'];
const OKI='<path d="M5 12l5 5 9-10"/>',KOI='<path d="M12 7v6M12 17h.01"/><circle cx="12" cy="12" r="9"/>';
const $=id=>document.getElementById(id);
const esc=s=>String(s==null?'':s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const fmt=s=>{s=Math.max(0,Math.ceil(s-1e-6));return String(Math.floor(s/60)).padStart(2,'0')+':'+String(s%60).padStart(2,'0');};
const fmtS=s=>{const n=s<0;s=Math.abs(Math.round(s));return (n?'−':'')+Math.floor(s/60)+':'+String(s%60).padStart(2,'0');};
const fmtH=s=>{s=Math.max(0,Math.round(s));const h=Math.floor(s/3600),m=Math.floor(s%3600/60),r=s%60;return (h?h+':'+String(m).padStart(2,'0'):m)+':'+String(r).padStart(2,'0');};
const hm=s=>{s=Math.round(s);return (Math.floor(s/3600)%24)+'h'+String(Math.floor(s%3600/60)).padStart(2,'0');};
const minL=d=>d%60?Math.floor(d/60)+'′'+String(d%60).padStart(2,'0'):(d/60)+' min';
const digits=t=>t.split('').map(c=>c===':'?'<span class="k">:</span>':'<span class="d">'+c+'</span>').join('');
const cap=s=>s?s.charAt(0).toUpperCase()+s.slice(1):s;
const md=s=>esc(s).replace(/\*\*(.+?)\*\*/g,'<b>$1</b>');

/* ---------- stockage ---------- */
const store={
  get(k,d){try{const v=localStorage.getItem('ct.'+k);return v==null?d:JSON.parse(v);}catch(e){return d;}},
  set(k,v){try{localStorage.setItem('ct.'+k,JSON.stringify(v));}catch(e){}},
  del(k){try{localStorage.removeItem('ct.'+k);}catch(e){}}
};
const DEF={bips:true,gong:true,voix:true,voixRounds:false,veille:true,test:false};
let R=Object.assign({},DEF,store.get('reglages',{}));
const saveR=()=>store.set('reglages',R);

function seances(){
  let l=store.get('seances',null);
  if(!l){l=(window.SEANCES_INCLUSES||[]).map(s=>({id:s.id,md:s.md,ajout:Date.now()}));store.set('seances',l);}
  return l;
}
function saveSeances(l){store.set('seances',l);}
function slug(c){const m=c.meta;return [(m.date||'').split('/').reverse().join('-'),m.public,m.lieu].filter(Boolean).join('-').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g,'').replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'')||('cours-'+Date.now());}
function dateOf(c){const d=(c.meta.date||'').match(/(\d{1,2})\/(\d{1,2})\/(\d{4})/);if(!d)return null;const h=(c.meta.heure||'00:00').match(/(\d+)[:h](\d+)/);return new Date(+d[3],+d[2]-1,+d[1],h?+h[1]:0,h?+h[2]:0);}
function startSec(c){const h=(c.meta.heure||'').match(/(\d+)[:h](\d+)/);return h?(+h[1])*3600+(+h[2])*60:null;}

/* ---------- navigation ---------- */
const VIEWS=['vHome','vImport','vSeance','vPrep','vRun','vEnd','vSettings'];
function show(v){VIEWS.forEach(x=>{$(x).hidden=x!==v;});window.scrollTo(0,0);
  if(v==='vHome')renderHome();if(v==='vSettings')renderSettings();if(v==='vPrep')renderPrep();}
document.addEventListener('click',e=>{const b=e.target.closest('[data-go]');if(b){e.preventDefault();show(b.dataset.go);}});
let toastT=null;
function toast(t){const el=$('toast');el.textContent=t;el.hidden=false;clearTimeout(toastT);toastT=setTimeout(()=>el.hidden=true,2600);}

/* ---------- accueil ---------- */
let CUR=null,CURID=null;
function renderHome(){
  const l=seances().map(s=>{let c=null;try{c=parseCours(s.md);}catch(e){}return {s,c,d:c?dateOf(c):null};}).filter(x=>x.c);
  const now=new Date();const today=new Date(now.getFullYear(),now.getMonth(),now.getDate());
  l.sort((a,b)=>{const pa=a.d&&a.d<today,pb=b.d&&b.d<today;if(pa!==pb)return pa?1:-1;return pa?(b.d-a.d):((a.d||0)-(b.d||0));});
  let firstNext=true;
  $('list').innerHTML=l.length?l.map(x=>{const c=x.c,m=c.meta;const past=x.d&&x.d<today;
    let k='À venir';
    if(x.d){const dd=new Date(x.d.getFullYear(),x.d.getMonth(),x.d.getDate());const diff=Math.round((dd-today)/864e5);
      k=diff===0?(x.d.getHours()>=17?'Ce soir':'Aujourd’hui'):diff===1?'Demain':past?'Passée':'À venir';
      k+=' · '+JOURS[x.d.getDay()].toLowerCase()+' '+String(x.d.getDate()).padStart(2,'0')+'/'+String(x.d.getMonth()+1).padStart(2,'0')+(m.heure?' · '+m.heure.replace(':','h'):'');}
    const cls=past?'past':(firstNext?'next':'');if(!past)firstNext=false;
    return '<button class="card '+cls+'" data-sid="'+esc(x.s.id)+'"><span class="k">'+esc(k)+'</span><span class="t">'+esc(m.theme||c.titre||'Séance')+'</span>'+
      (m.sous_theme?'<span class="s">'+esc(cap(m.sous_theme))+'</span>':'')+
      '<span class="compo">'+c.blocs.map(b=>'<i style="flex-grow:'+b.duree+';background:'+COL[b.section]+'"></i>').join('')+'</span>'+
      '<span class="s">'+esc([m.public,m.lieu,m.duree].filter(Boolean).join(' · '))+'</span></button>';}).join('')
    :'<div class="empty">Aucune séance. Importe le .md envoyé par Claude.</div>';
  const ios=/iPhone|iPad|iPod/.test(navigator.userAgent);const standalone=window.navigator.standalone||matchMedia('(display-mode: standalone)').matches;
  $('install').hidden=!(ios&&!standalone);
  const run=store.get('run',null);
  const ok=run&&!run.finished&&(Date.now()-run.saved)<4*3600e3&&seances().some(s=>s.id===run.sid);
  $('resume').hidden=!ok;
  if(ok){let t='';try{const c=parseCours(seances().find(s=>s.id===run.sid).md);t=(c.meta.theme||'')+' · bloc '+(c.blocs.length?(c.blocs[segsOf(c)[run.i].bi].titre):'');}catch(e){}$('resumeTxt').textContent=t;}
}
$('list').addEventListener('click',e=>{const b=e.target.closest('[data-sid]');if(b)openSeance(b.dataset.sid);});
$('resume').addEventListener('click',e=>{e.preventDefault();resumeRun();});

/* ---------- séance du jour ---------- */
let openBloc=-1;
function openSeance(id){const s=seances().find(x=>x.id===id);if(!s)return;CUR=parseCours(s.md);segsOf(CUR);CURID=id;openBloc=-1;checked={};renderSeance();show('vSeance');}
function mats(c){const seen=new Map();c.blocs.forEach(b=>{(b.materiel||'').split(/,\s*/).map(x=>x.trim()).filter(x=>x&&!/mains nues/i.test(x)).forEach(x=>{const k=x.toLowerCase().replace(/ pour l.*$/,'').replace(/ \(.*\)$/,'');if(!seen.has(k))seen.set(k,{nom:cap(k),bloc:b});});});return [...seen.values()];}
function renderSeance(){
  const c=CUR,m=c.meta,d=dateOf(c),st=startSec(c);
  $('sEyebrow').textContent=[d?JOURS[d.getDay()]+' '+String(d.getDate()).padStart(2,'0')+'/'+String(d.getMonth()+1).padStart(2,'0'):'',m.heure?m.heure.replace(':','h'):'',(m.lieu||'').split(' ')[0],m.duree].filter(Boolean).join(' · ');
  $('sTitle').textContent=m.theme||c.titre;
  $('sSub').textContent=[m.public,m.coach?'Coach '+m.coach:''].filter(Boolean).join(' · ');
  $('sObj').hidden=!c.objectif;$('sObj').innerHTML='<b>Objectif :</b> '+esc(c.objectif);
  $('sCompo').innerHTML=c.blocs.map(b=>'<i style="flex-grow:'+b.duree+';background:'+COL[b.section]+'"></i>').join('');
  let acc=0;
  $('sTl').innerHTML=c.blocs.map((b,i)=>{const t=st!=null?hm(st+acc):'+'+Math.round(acc/60)+'′';acc+=b.duree;const op=i===openBloc;
    let h='<button class="row" data-bi="'+i+'" aria-expanded="'+op+'"><time>'+t+'</time><i style="background:'+COL[b.section]+'"></i><span>'+esc(b.titre)+'</span><em>'+Math.round(b.duree/60)+'′</em></button>';
    if(op){h+='<div class="detail" style="--c:'+COL[b.section]+'">'+(b.description.length?'<div>'+md(b.description.join(' '))+'</div>':'')+
      (b.consigne?'<div class="cons"><b>Consigne</b><br>'+md(cap(b.consigne))+'</div>':'')+
      (b.materiel?'<div><b style="color:var(--text)">Matériel :</b> '+esc(b.materiel)+'</div>':'')+
      '<div class="seqs">'+b.sequences.map(q=>'<div class="seq"><span class="ty" style="color:'+(q.type==='travail'?COL[b.section]:q.type==='repos'?'#8E9096':'#C9CBD0')+'">'+TYPE[q.type]+'</span><span class="lb">'+esc(q.label)+(q.mid?' · ⇄':'')+'</span><span class="du">'+fmtS(q.d)+'</span></div>').join('')+'</div>'+
      '<button class="btn small" data-from="'+i+'">Lancer depuis ce bloc</button></div>';}
    return h;}).join('');
  $('sMat').innerHTML=mats(c).map(x=>'<span>'+esc(x.nom)+'</span>').join('');
}
$('sTl').addEventListener('click',e=>{const f=e.target.closest('[data-from]');if(f){startRun(+f.dataset.from);return;}const r=e.target.closest('[data-bi]');if(!r)return;const i=+r.dataset.bi;openBloc=openBloc===i?-1:i;renderSeance();});
$('bDelete').addEventListener('click',()=>{if($('bDelete').dataset.armed){saveSeances(seances().filter(s=>s.id!==CURID));delete $('bDelete').dataset.armed;$('bDelete').textContent='Retirer cette séance';toast('Séance retirée');show('vHome');}
  else{$('bDelete').dataset.armed='1';$('bDelete').textContent='Toucher encore pour confirmer';setTimeout(()=>{delete $('bDelete').dataset.armed;$('bDelete').textContent='Retirer cette séance';},4000);}});

/* ---------- préparation ---------- */
let checked={};
function toggleRow(key,label,sub){return '<button aria-pressed="'+!!R[key]+'" data-set="'+key+'"><span class="w">'+label+(sub?'<small>'+sub+'</small>':'')+'</span><span class="sw"></span></button>';}
function renderPrep(){
  if(!CUR)return;const c=CUR,st=startSec(c);
  $('pEyebrow').textContent=(c.meta.theme||'')+(c.meta.heure?' · '+c.meta.heure.replace(':','h'):'');
  const M=mats(c);$('pMatLab').hidden=!M.length;$('pMat').hidden=!M.length;
  $('pMatLab').textContent='Matériel à sortir · '+M.filter(x=>checked[x.nom]).length+'/'+M.length;
  $('pMat').innerHTML=M.map(x=>'<button aria-pressed="'+!!checked[x.nom]+'" data-mat="'+esc(x.nom)+'"><span class="bx"><svg viewBox="0 0 24 24">'+(checked[x.nom]?OKI:'')+'</svg></span><span class="w">'+esc(x.nom)+'</span><span class="when">dès '+(st!=null?hm(st+x.bloc.start):'+'+Math.round(x.bloc.start/60)+'′')+'</span></button>').join('');
  $('pToggles').innerHTML=toggleRow('bips','Bips 3-2-1 et gong')+toggleRow('voix','Voix : blocs et changements de rôle')+toggleRow('veille','Écran toujours allumé')+(R.test?toggleRow('test','Mode essai ×10','Le chrono va 10 fois plus vite'):'');
}
$('pMat').addEventListener('click',e=>{const b=e.target.closest('[data-mat]');if(!b)return;checked[b.dataset.mat]=!checked[b.dataset.mat];renderPrep();});
function onToggle(e){const b=e.target.closest('[data-set]');if(!b)return;const k=b.dataset.set;R[k]=!R[k];if(k==='bips')R.gong=R.bips;saveR();b.setAttribute('aria-pressed',R[k]);if(!$('vPrep').hidden)renderPrep();}
['pToggles','setSound','setScreen','setTest'].forEach(id=>$(id).addEventListener('click',onToggle));
function renderSettings(){
  $('setSound').innerHTML=toggleRow('bips','Bips 3-2-1')+toggleRow('gong','Gong de fin de séquence')+toggleRow('voix','Voix : nouveaux blocs, changements de rôle')+toggleRow('voixRounds','Voix : chaque round');
  $('setScreen').innerHTML=toggleRow('veille','Écran toujours allumé','Pendant l’animation du cours');
  $('setTest').innerHTML=toggleRow('test','Mode essai ×10','Pour tester une séance en 9 minutes');
  $('version').textContent='Chrono Tatami '+VERSION;
}

/* ---------- import ---------- */
let pending=null;
function check(txt){let r;try{r=parseCours(txt);}catch(e){r={meta:{},sections:[],blocs:[],total:0,errors:['Lecture impossible : '+e.message]};}
  const ok=!r.errors.length&&r.total>0&&r.blocs.length>0;
  $('report').hidden=false;$('verdict').className='verdict '+(ok?'ok':'ko');
  $('verdict').innerHTML='<svg viewBox="0 0 24 24">'+(ok?OKI:KOI)+'</svg>'+(ok?'Tout tombe juste':'À corriger');
  const nseq=r.blocs.reduce((a,b)=>a+b.sequences.length,0),nmid=r.blocs.reduce((a,b)=>a+b.sequences.filter(q=>q.mid).length,0);
  $('checks').innerHTML=[['Séquences / prévu '+esc(r.meta.duree||'?'),fmtH(r.total)],['Sections',r.sections.length],['Blocs',r.blocs.length],['Séquences minutées',nseq],['Changements de rôle',nmid],['Séance',esc([r.meta.theme,r.meta.date].filter(Boolean).join(' · ')||'—'),1]]
    .map(x=>'<li><span>'+x[0]+'</span><b'+(x[2]?' class="sm"':'')+'>'+x[1]+'</b></li>').join('');
  $('errs').innerHTML=r.errors.map(e=>'<li>'+esc(e)+'</li>').join('');
  pending=ok?{txt,r}:null;$('bAddSeance').disabled=!ok;return ok;}
$('bCheck').addEventListener('click',()=>check($('mdIn').value));
$('fileIn').addEventListener('change',e=>{const f=e.target.files&&e.target.files[0];if(!f)return;const rd=new FileReader();rd.onload=()=>{$('mdIn').value=String(rd.result);check(String(rd.result));};rd.readAsText(f,'utf-8');e.target.value='';});
$('bAddSeance').addEventListener('click',()=>{if(!pending)return;const id=slug(pending.r);const l=seances().filter(s=>s.id!==id);l.push({id,md:pending.txt,ajout:Date.now()});saveSeances(l);
  $('mdIn').value='';$('report').hidden=true;$('bAddSeance').disabled=true;pending=null;toast('Séance ajoutée');openSeance(id);});

/* ---------- son, voix, veille ---------- */
let AC=null;
function ac(){if(!AC){try{AC=new (window.AudioContext||window.webkitAudioContext)();}catch(e){}}if(AC&&AC.state!=='running')AC.resume().catch(()=>{});return AC;}
function unlockAudio(){try{if(navigator.audioSession)navigator.audioSession.type='playback';}catch(e){}
  const a=ac();if(a){const b=a.createBuffer(1,1,22050),s=a.createBufferSource();s.buffer=b;s.connect(a.destination);s.start(0);}
  try{if('speechSynthesis' in window){const u=new SpeechSynthesisUtterance(' ');u.volume=0;speechSynthesis.speak(u);}}catch(e){}}
const fast=()=>speed()>10;
function tone(f,dur,type,vol,when){const a=ac();if(!a)return;const t=a.currentTime+(when||0);const o=a.createOscillator(),g=a.createGain();o.type=type||'square';o.frequency.value=f;g.gain.setValueAtTime(.0001,t);g.gain.exponentialRampToValueAtTime(vol||.12,t+.01);g.gain.exponentialRampToValueAtTime(.0001,t+dur);o.connect(g).connect(a.destination);o.start(t);o.stop(t+dur+.05);}
const beep=()=>{if(R.bips)tone(880,.14,'square',.12);};
const gong=()=>{if(!R.gong)return;tone(196,1.7,'sine',.5);tone(294,1.4,'sine',.26);tone(392,1,'triangle',.12);};
const dbl=()=>{if(!R.bips)return;tone(1046,.11,'square',.1);tone(1046,.11,'square',.1,.17);};
const tri=()=>{if(!R.bips)return;[0,.15,.3].forEach(w=>tone(1318,.1,'square',.1,w));};
let VOICE=null;
function pickVoice(){try{const v=speechSynthesis.getVoices().filter(x=>/^fr/i.test(x.lang));VOICE=v.find(x=>/fr-FR/i.test(x.lang))||v[0]||null;}catch(e){}}
if('speechSynthesis' in window){pickVoice();try{speechSynthesis.onvoiceschanged=pickVoice;}catch(e){}}
function say(t,force){if(!(R.voix||force)||!('speechSynthesis' in window))return;try{speechSynthesis.cancel();const u=new SpeechSynthesisUtterance(t.replace(/(\d)\/(\d)/g,'$1 sur $2').replace(/[·«»⇄]/g,' '));u.lang='fr-FR';if(VOICE)u.voice=VOICE;u.rate=1.05;speechSynthesis.speak(u);}catch(e){}}
let lock=null;
async function getLock(){if(!R.veille)return;try{if('wakeLock' in navigator&&!lock){lock=await navigator.wakeLock.request('screen');lock.addEventListener('release',()=>{lock=null;});}}catch(e){lock=null;}}
function releaseLock(){try{lock&&lock.release();}catch(e){}lock=null;}

/* ---------- moteur ---------- */
let C=null,SEGS=[],TOTAL=0;
const S={sid:null,i:0,rem:0,run:false,extra:0,added:0,adj:{},startWall:0,finished:false,lastBloc:-1};
function segsOf(c){const out=[];let acc=0;c.blocs.forEach((b,bi)=>{b.start=acc;b.sequences.forEach((q,si)=>{out.push(Object.assign({},q,{bi,si,start:acc}));acc+=q.d;});});return out;}
const speed=()=>R.test?10:1;
function prepRun(c){C=c;SEGS=segsOf(c);TOTAL=SEGS.reduce((a,q)=>a+q.d,0);}
function persist(){store.set('run',{sid:S.sid,i:S.i,rem:S.rem,run:S.run,extra:S.extra,added:S.added,adj:S.adj,startWall:S.startWall,finished:S.finished,saved:Date.now()});}
function startRun(fromBloc){
  unlockAudio();prepRun(CUR);
  const i0=fromBloc?SEGS.findIndex(q=>q.bi===fromBloc):0;
  Object.assign(S,{sid:CURID,i:Math.max(0,i0),run:true,extra:0,added:0,adj:{},startWall:Date.now(),finished:false,lastBloc:-1,stoppedAt:null,notDone:0,endWall:0});
  S.rem=SEGS[S.i].d;roleUntil=0;
  enterRun();onEnter(false,true);persist();
}
function resumeRun(){
  const run=store.get('run',null);const s=run&&seances().find(x=>x.id===run.sid);if(!s)return;
  unlockAudio();CUR=parseCours(s.md);CURID=s.id;prepRun(CUR);
  Object.assign(S,{sid:run.sid,i:Math.min(run.i,SEGS.length-1),rem:run.rem,run:run.run,extra:run.extra||0,added:run.added||0,adj:run.adj||{},startWall:run.startWall||Date.now(),finished:false});
  S.lastBloc=SEGS[S.i].bi;
  if(S.run)advance((Date.now()-run.saved)/1000*speed(),true);
  enterRun();if(!S.run)openSheet();
}
function enterRun(){show('vRun');$('sheet').hidden=true;last=0;getLock();render(true);loop();}
let last=0,raf=0,iv=0,saveT=0;
function loop(){cancelAnimationFrame(raf);clearInterval(iv);
  const step=()=>{tick();if(!$('vRun').hidden)raf=requestAnimationFrame(step);};raf=requestAnimationFrame(step);
  iv=setInterval(()=>{if($('vRun').hidden){clearInterval(iv);return;}tick();},250);}
function tick(){
  const now=Date.now();if(!last)last=now;const dw=(now-last)/1000;last=now;
  if(S.run&&!S.finished)advance(dw*speed(),dw>2);
  if(now-saveT>1000){saveT=now;if(!S.finished)persist();}
  render(false);
}
function advance(dt,silent){
  const prev=S.rem;S.rem-=dt;
  const q=SEGS[S.i],cd=q.d+S.extra;
  if(!silent&&!fast()){
    [3,2,1].forEach(th=>{if(prev>th&&S.rem<=th&&cd>6)beep();});
    if(q.mid&&prev>cd/2&&S.rem<=cd/2){tri();say(q.mid);showRole(q);}
    const nx=SEGS[S.i+1];if(nx&&nx.bi!==q.bi&&prev>10&&S.rem<=10)say('Dans 10 secondes : '+C.blocs[nx.bi].titre);
  }
  while(S.rem<=0&&!S.finished){
    const carry=-S.rem;
    if(S.i>=SEGS.length-1){S.rem=0;finish(silent);break;}
    if(SEGS[S.i+1].bi===SEGS[S.i].bi&&!silent&&!fast())gong();
    S.i++;S.extra=0;S.rem=SEGS[S.i].d-carry;onEnter(silent||fast(),false);
  }
}
function onEnter(silent,first){
  const q=SEGS[S.i],b=C.blocs[q.bi];
  if(q.bi!==S.lastBloc){S.lastBloc=q.bi;if(!silent){if(!first)gong();say(b.titre);}}
  else if(!silent){if(q.type==='repos'){if(R.voixRounds)say(q.label);}else{dbl();if(R.voixRounds)say(q.label.split('·')[0]);}}
}
function finish(silent){
  S.finished=true;S.run=false;S.endWall=Date.now();releaseLock();persist();
  if(!silent){gong();say('Fin de la séance. Salut.',true);}
  setTimeout(()=>{renderEnd();show('vEnd');},silent?0:1800);
}

/* ---------- affichage ---------- */
let roleUntil=0,lastKey='';
function showRole(q){const b=C.blocs[q.bi];$('ovRole').style.setProperty('--rc',COL[b.section]);
  $('roleK').textContent='Mi-round · '+q.label.split('·')[0].trim();roleUntil=Date.now()+3000;}
function render(force){
  if($('vRun').hidden||!SEGS.length)return;
  const q=SEGS[S.i],b=C.blocs[q.bi],cd=q.d+S.extra,c=COL[b.section];
  const frac=Math.max(0,Math.min(1,S.rem/cd));
  const roleOn=Date.now()<roleUntil&&!S.finished;
  const nx=SEGS[S.i+1];const nextOn=!S.finished&&nx&&nx.bi!==q.bi&&S.rem<=10&&!roleOn;
  const key=[S.i,Math.ceil(S.rem),S.run,S.added,S.finished,roleOn,nextOn,Math.round(frac*500)].join('|');
  if(!force&&key===lastKey)return;lastKey=key;
  const V=$('vRun');V.className='run m-'+q.type;V.style.setProperty('--c',c);
  $('pIco').innerHTML=ICO[q.type];$('pTxt').textContent=MODE[q.type];
  $('ttl').textContent=b.titre;
  const n=b.sequences.length;
  $('rp').innerHTML=n>1&&n<=12?b.sequences.map((x,k)=>'<i class="'+(k<q.si?'d':k===q.si?'c':'')+'"></i>').join(''):'';
  $('rc').textContent=n>1?(q.si+1)+'/'+n:minL(b.duree);
  const W=((1-frac)*100).toFixed(2);
  $('fill').style.width=W+'%';$('bar8').style.width=W+'%';
  const A=$('layA'),B=$('layB');const dg=digits(fmt(S.rem));
  A.firstChild.textContent=B.firstChild.textContent=q.label;
  A.lastChild.innerHTML=B.lastChild.innerHTML=dg;
  if(q.type==='travail'){A.style.color='#0B0B0C';B.style.color=c;A.style.clipPath='inset(0 '+(100-W)+'% 0 0)';B.style.clipPath='inset(0 0 0 '+W+'%)';}
  else{const col=q.type==='repos'?c:'#F2EFE6';A.style.color=col;B.style.color=col;A.style.clipPath='none';B.style.clipPath='inset(0 0 0 100%)';}
  let nt='Fin de séance',nd='';
  if(nx){if(nx.bi!==q.bi){nt=C.blocs[nx.bi].titre;nd=minL(C.blocs[nx.bi].duree);}else{nt=nx.label;nd=fmtS(nx.d);}}
  $('nx').textContent=nt;$('nd').textContent=nd;
  const el=q.start+(cd-S.rem);
  $('el').textContent=fmtH(el);$('pg').style.width=(Math.min(1,el/TOTAL)*100).toFixed(1)+'%';
  const d=new Date(Date.now()+Math.max(0,TOTAL-(q.start+q.d)+S.rem)*1000/speed());
  $('fin').textContent='FIN '+d.getHours()+'H'+String(d.getMinutes()).padStart(2,'0');
  $('ovRole').classList.toggle('on',roleOn);
  if(roleOn)$('roleS').textContent=b.titre+' · encore '+fmtS(Math.ceil(S.rem));
  $('ovNext').classList.toggle('on',!!nextOn);
  if(nextOn){const nb=C.blocs[nx.bi],r=Math.ceil(S.rem);$('ovNext').style.setProperty('--nc',COL[nb.section]);
    $('cnt').textContent=r;$('ticks').innerHTML=Array.from({length:10},(_,k)=>'<i class="'+(k>=10-r?'on':'')+'"></i>').join('');
    $('nK').textContent='Phase suivante · '+SECN[nb.section];$('nT').textContent=nb.titre;
    const nw=nb.sequences.filter(x=>x.type==='travail').length;
    $('nS').textContent=minL(nb.duree)+(nw>1?' · '+nw+' séquences de travail':'');
    $('nM').innerHTML=nb.materiel?nb.materiel.split(/,\s*/).filter(x=>!/mains nues/i.test(x)).map(x=>'<span>'+esc(cap(x))+'</span>').join(''):'';
    $('nE').textContent='Se termine : '+b.titre+' · '+q.label;$('nR').textContent=fmtS(Math.ceil(S.rem));}
  if(!$('sheet').hidden)renderSheet();
}

/* ---------- pause ---------- */
function openSheet(){S.run=false;persist();renderSheet();$('sheet').hidden=false;}
function renderSheet(){const q=SEGS[S.i],b=C.blocs[q.bi];$('shDig').textContent=fmt(S.rem);$('shTtl').textContent=b.titre;$('shSub').textContent=q.label;
  $('shAdd').textContent=S.added?((S.added>0?'+':'')+fmtS(S.added)+' sur la séance'):'';}
['tap1','tap2'].forEach(id=>$(id).addEventListener('click',()=>{if(S.finished)return;openSheet();}));
$('bResume').addEventListener('click',()=>{unlockAudio();$('sheet').hidden=true;S.run=true;last=0;getLock();persist();render(true);});
function adjust(sec){const q=SEGS[S.i];const ns=Math.max(1,S.rem+sec);const real=ns-S.rem;S.rem=ns;S.extra+=real;S.added+=real;S.adj[q.bi]=(S.adj[q.bi]||0)+real;persist();render(true);renderSheet();}
$('bPlus').addEventListener('click',()=>adjust(30));
$('bMinus').addEventListener('click',()=>adjust(-30));
$('bBack').addEventListener('click',()=>{const q=SEGS[S.i];const done=q.d+S.extra-S.rem;
  if(done>3){S.adj[q.bi]=(S.adj[q.bi]||0)+done;S.added+=done;S.rem=q.d;S.extra=0;}
  else if(S.i>0){S.i--;S.rem=SEGS[S.i].d;S.extra=0;const p=SEGS[S.i];S.adj[p.bi]=(S.adj[p.bi]||0)+p.d;S.added+=p.d;S.lastBloc=p.bi;}
  roleUntil=0;persist();render(true);renderSheet();});
$('bSkip').addEventListener('click',()=>{const q=SEGS[S.i];S.adj[q.bi]=(S.adj[q.bi]||0)-S.rem;S.added-=S.rem;
  if(S.i>=SEGS.length-1){S.rem=0;$('sheet').hidden=true;finish(true);return;}
  S.i++;S.rem=SEGS[S.i].d;S.extra=0;onEnter(true);S.lastBloc=SEGS[S.i].bi;roleUntil=0;persist();render(true);renderSheet();});
$('bStop').addEventListener('click',()=>{if($('bStop').dataset.armed){delete $('bStop').dataset.armed;$('bStop').textContent='Terminer la séance';
    let left=S.rem;for(let k=S.i+1;k<SEGS.length;k++){left+=SEGS[k].d;}
    const cb=SEGS[S.i].bi;for(let k=S.i;k<SEGS.length&&SEGS[k].bi===cb;k++){S.adj[cb]=(S.adj[cb]||0)-(k===S.i?S.rem:SEGS[k].d);}
    S.added-=left;S.stoppedAt=C.blocs[cb].titre;S.notDone=C.blocs.length-1-cb;$('sheet').hidden=true;finish(true);}
  else{$('bStop').dataset.armed='1';$('bStop').textContent='Toucher encore pour arrêter';setTimeout(()=>{delete $('bStop').dataset.armed;$('bStop').textContent='Terminer la séance';},4000);}});
document.addEventListener('keydown',e=>{if($('vRun').hidden||e.target.closest('textarea,input'))return;if(e.code==='Space'){e.preventDefault();if($('sheet').hidden)openSheet();else $('bResume').click();}});
document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible'&&!$('vRun').hidden){if(S.run)getLock();tick();}});

/* ---------- fin de séance ---------- */
function bilanMd(){
  const m=C.meta,real=TOTAL+S.added,wall=((S.endWall||Date.now())-S.startWall)/1000;
  const lastDone=C.blocs.length-1-(S.notDone||0);const gaps=C.blocs.map((b,i)=>({b,a:Math.round(S.adj[i]||0),i})).filter(x=>x.a&&x.i<=lastDone);
  let t='---\nformat: chrono-tatami/bilan-1\nseance: '+(m.date||'')+' · '+(m.public||'')+' · '+(m.lieu||'')+'\n---\n\n# Bilan · '+(m.theme||C.titre)+' · '+(m.date||'')+'\n\n';
  t+='- Prévu : '+fmtH(TOTAL)+'\n- Réel (chrono) : '+fmtH(real)+'\n- À l’horloge, pauses comprises : '+fmtH(wall/(R.test?10:1))+'\n';
  if(S.stoppedAt)t+='- Séance arrêtée pendant : '+S.stoppedAt+(S.notDone?' ('+S.notDone+' bloc(s) non faits)':'')+'\n';
  t+='\n## Écarts par bloc\n'+(gaps.length?gaps.map(x=>'- '+x.b.titre+' : '+(x.a>0?'+':'')+fmtS(x.a)).join('\n'):'- Aucun : tous les blocs à l’heure')+'\n';
  const note=$('eNote').value.trim();t+='\n## Note du coach\n'+(note||'(aucune)')+'\n';
  return t;
}
function renderEnd(){
  const m=C.meta,real=TOTAL+S.added;
  $('eEyebrow').textContent='Séance terminée · '+(m.theme||'');
  $('ePlan').textContent=fmtH(TOTAL);$('eReal').textContent=fmtH(real);$('eReal').style.color=Math.abs(S.added)>=1?'#FF9A4D':'';
  const lastDone=C.blocs.length-1-(S.notDone||0);const gaps=C.blocs.map((b,i)=>({b,a:Math.round(S.adj[i]||0),i})).filter(x=>x.a&&x.i<=lastDone);
  const n0=C.blocs.length-gaps.length-(S.notDone||0);
  $('eGaps').innerHTML='<span class="k">Écarts</span>'+gaps.map(x=>'<div class="gap"><b>'+(x.a>0?'+':'')+fmtS(x.a)+'</b><span>'+esc(x.b.titre)+'</span></div>').join('')+
    (n0?'<div class="gap"><b class="z">0:00</b><span>'+(gaps.length?'Les '+n0+' autres blocs':'Tous les blocs')+', à l’heure</span></div>':'')+(S.stoppedAt?'<div class="gap"><span>Arrêtée pendant « '+esc(S.stoppedAt)+' »'+(S.notDone?', '+S.notDone+' bloc'+(S.notDone>1?'s':'')+' non fait'+(S.notDone>1?'s':''):'')+'</span></div>':'');
  const deb=C.blocs.map(b=>b.debrief).filter(Boolean)[0];
  $('eDeb').hidden=!deb;$('eDeb').innerHTML='<span class="k">Débrief</span>'+esc(cap(deb||''));
  $('eNote').value='';store.del('run');
}
$('bShare').addEventListener('click',async()=>{
  const md=bilanMd();const h=store.get('bilans',[]);h.push({sid:S.sid,date:Date.now(),md});store.set('bilans',h.slice(-50));
  try{if(navigator.share){await navigator.share({title:'Bilan Chrono Tatami',text:md});return;}}catch(e){if(e&&e.name==='AbortError')return;}
  try{await navigator.clipboard.writeText(md);toast('Bilan copié : colle-le à Claude');}catch(e){$('eNote').value=md;toast('Copie le bilan affiché dans la note');}
});

/* ---------- démarrage ---------- */
$('bGo').addEventListener('click',()=>startRun(0));
if('serviceWorker' in navigator&&window.isSecureContext){window.addEventListener('load',()=>{navigator.serviceWorker.register('sw.js').catch(()=>{});});}
show('vHome');
window.__ct={S,get C(){return C;},get SEGS(){return SEGS;}};
})();
