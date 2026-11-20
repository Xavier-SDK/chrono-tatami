// Lecteur du format de cours chrono-tatami/1 (Markdown)
function parseCours(md){
  const lines=md.replace(/\r/g,'').split('\n');
  const meta={},sections=[],errors=[];let i=0;
  if(lines[0].trim()==='---'){i=1;while(i<lines.length&&lines[i].trim()!=='---'){const m=lines[i].match(/^([\w_]+)\s*:\s*(.*)$/);if(m)meta[m[1]]=m[2].trim();i++;}i++;}
  const dur=s=>{const m=s.match(/(\d+):(\d{2})/);return m?(+m[1])*60+(+m[2]):null;};
  const mins=s=>{const h=s.match(/(\d+)\s*h\s*(\d+)?/);if(h)return (+h[1])*60+(+(h[2]||0));const m=s.match(/(\d+)\s*min/);return m?+m[1]:null;};
  const kind=t=>{t=t.toLowerCase();if(/ouvert|accueil/.test(t))return'ouverture';if(/échauf|echauf/.test(t))return'echauffement';if(/pratique|restitution|combat|sparring/.test(t))return'pratique';if(/calme|étire|etire/.test(t))return'calme';return'techniques';};
  let sec=null,bloc=null,objectif='',titre='';
  for(;i<lines.length;i++){
    const L=lines[i];let m;
    if((m=L.match(/^#\s+(.*)/))){titre=m[1].trim();continue;}
    if((m=L.match(/^>\s*\*\*Objectif\s*:\*\*\s*(.*)/i))){objectif=m[1].trim();continue;}
    if((m=L.match(/^##\s+(.*?)\s*·\s*(.*)$/))||(m=L.match(/^##\s+(.*)$/))){sec={titre:m[1].trim(),prevu:m[2]?mins(m[2]):null,kind:kind(m[1]),blocs:[]};sections.push(sec);bloc=null;continue;}
    if((m=L.match(/^###\s+(.*?)\s*·\s*(.*)$/))||(m=L.match(/^###\s+(.*)$/))){
      if(!sec){sec={titre:'Séance',prevu:null,kind:'techniques',blocs:[]};sections.push(sec);}
      bloc={titre:m[1].trim(),prevu:m[2]?mins(m[2]):null,section:/^salut/i.test(m[1].trim())?'ouverture':sec.kind,description:[],consigne:'',materiel:'',debrief:'',sequences:[]};sec.blocs.push(bloc);continue;}
    if(!bloc)continue;
    if((m=L.match(/^-\s*\[(travail|repos|consigne)\]\s*(.*)$/i))){
      const parts=m[2].split(/\s*·\s*/);let mid='';const k=parts.findIndex(p=>p.startsWith('⇄'));if(k>=0){mid=parts[k].replace('⇄','').trim();parts.splice(k,1);}
      const d=dur(parts[parts.length-1]||'');if(d==null){errors.push('Durée manquante : « '+L.trim()+' »');continue;}
      parts.pop();bloc.sequences.push({type:m[1].toLowerCase(),label:parts.join(' · '),d,mid});continue;}
    if((m=L.match(/^\*\*Consigne\s*:\*\*\s*(.*)/i))){bloc.consigne=m[1].trim();continue;}
    if((m=L.match(/^\*\*Matériel\s*:\*\*\s*(.*)/i))){bloc.materiel=m[1].trim();continue;}
    if((m=L.match(/^\*\*Débrief\s*:\*\*\s*(.*)/i))){bloc.debrief=m[1].trim();continue;}
    if(L.trim())bloc.description.push(L.trim());
  }
  let total=0;const blocs=[];
  sections.forEach(s=>{let st=0;s.blocs.forEach(b=>{b.duree=b.sequences.reduce((a,q)=>a+q.d,0);st+=b.duree;
    if(!b.sequences.length)errors.push('« '+b.titre+' » n’a aucune séquence minutée.');
    else if(b.prevu!=null&&b.duree!==b.prevu*60)errors.push('« '+b.titre+' » : séquences = '+(b.duree/60)+' min, prévu '+b.prevu+' min.');
    blocs.push(b);});s.duree=st;total+=st;
    if(s.prevu!=null&&st!==s.prevu*60)errors.push('Section « '+s.titre+' » : '+(st/60)+' min, prévu '+s.prevu+' min.');});
  const prevu=meta.duree?mins(meta.duree):null;
  if(prevu!=null&&total!==prevu*60)errors.push('Total '+(total/60)+' min pour une séance de '+prevu+' min.');
  return {meta,titre,objectif,sections,blocs,total,errors};
}
if(typeof module!=='undefined')module.exports=parseCours;
