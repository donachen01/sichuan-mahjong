"""Source-bound study fixtures, declared reconstructions, independent exact partitions."""
from pathlib import Path
from functools import lru_cache
import json,re,hashlib
D=Path(__file__).parent;R=Path.cwd()
sections=[('5.5',36,37),('6.1',38,40),('6.2',41,43),('6.3',44,46),('6.4.1',47,52),('6.4.2',53,57),('6.4.3',58,61),('6.4.4',62,66),('6.5.1',67,71),('6.5.2',72,77),('7.1',78,82),('7.2',83,85)]
source=[x for x in json.load(open('research/technical_theory_20260928/reviewed-hands.json')) if x['book']=='lower' and int(x['page'])>=36]
@lru_cache(None)
def wins(a,sets):
 if sum(a)!=sets*3+2:return False
 for i,n in enumerate(a):
  if n<2:continue
  b=list(a);b[i]-=2
  if groups(tuple(b),sets):return True
 return False
@lru_cache(None)
def groups(a,n):
 if n==0:return not any(a)
 i=next((i for i,v in enumerate(a) if v),-1)
 if i<0:return False
 b=list(a)
 if b[i]>=3:
  b[i]-=3
  if groups(tuple(b),n-1):return True
  b[i]+=3
 if i%9<7 and b[i+1]>0 and b[i+2]>0:
  for t in (i,i+1,i+2):b[t]-=1
  if groups(tuple(b),n-1):return True
 return False

def seven(h):return sum(h)==14 and all(n%2==0 for n in h) and sum(n//2 for n in h)==7

def wait(h,ex,dq):
 if any(h[dq*9:dq*9+9]):return []
 result=[]
 for t in range(27):
  if t//9==dq or h[t]+ex[t]>=4:continue
  b=h[:];b[t]+=1
  if wins(tuple(b),(sum(h)-1)//3) or (not any(ex) and seven(b)):result.append(t)
 return result

def tile(s):return {'s':0,'p':9,'m':18}[s[0]]+int(s[1])-1
# Last draw and offered tile taken from the source; appended draws for 13-tile
# abstract shapes are declared, not attributed to the author.
draws={'5-12':'p4','5-13':'m2','5-14':'m2','5-15':'p7','6-4':'m7','6-5A':'p1','6-5B':'p8','6-5C':'s4','6-5D':'s4','6-9':'p7','6-10':'p7','6-12A':'m5','6-12B':'m9','6-12C':'m8','6-19A':'p8','6-19B':'p8','6-19C':'p4','6-20A':'s3','6-20B':'s1','6-20C':'s6','6-20D':'s6','6-22A':'m2','6-22B':'m5','6-22C':'m1'}
offers={'6-21':['m2','m3','m3'],'6-23':['m4'],'6-24':['p3'],'6-25':['p2','p5','p9'],'6-26':['p3','p4','p5','p7'],'6-27':['p3','p6','p8'],'6-28':['m2','m4'],'7-6':['p9']}
cases=[];structures=[]
for row in source:
 h=row['hand18'][:];m=row['typed_melds'];ex=row['exposed_counts'][:];key=row['case']+(row['variant'] if row['variant']!='base' else '')
 dq=next(i for i in range(3) if not any((h[t]+ex[t]) for t in range(i*9,i*9+9)))
 major=max(range(3),key=lambda s:sum(h[s*9:s*9+9])+sum(ex[s*9:s*9+9]));own=1
 op=[0,1,2]
 if row['case'].startswith('6-') and int(row['page'])<67:
  op=[major,major,next(s for s in range(3) if s!=major)]
 if row['case']=='6-9':op=[major]*3
 if row['case']=='6-10':op=[0,0,0]
 if row['case'] in ['6-23','6-24','6-25','6-26','6-27','6-28']:op=[major,major,next(s for s in range(3) if s!=major)]
 sec=next(s for s,a,b in sections if a<=int(row['page'])<=b)
 # Every source hand gets its own structural table, including partial core forms.
 geometry=[]
 if sum(h)%3==2:
  for t,n in enumerate(h):
   if n:
    b=h[:];b[t]-=1;geometry.append({'discard':t,'waits':wait(b,ex,dq)})
 else:geometry=[{'discard':-1,'waits':wait(h,ex,dq)}]
 structures.append({'id':row['id'],'hand':h,'melds':m,'exposed':ex,'dq':dq,'rows':geometry,'source_case':row['case'],'section':sec})
 base=dict(id=row['id'],source=row['id'],section=sec,page=int(row['page']),hand=h,melds=m,exposed=ex,dq=dq,opponent_dq=op,wall=35 if int(row['page'])<78 else 15,draw=tile(draws[key]) if key in draws else next(t for t,n in enumerate(h) if n),note=row['note'],known=[],winners=[])
 if row['case']=='6-4':base['hand']=h[:];base['hand'][tile('m7')]+=1;base['wall']=0
 if row['case'] in ['6-8','6-6','6-9','6-12','6-13']:base['wall']=43
 if row['case'] in ['6-15','6-16','6-17','6-18','6-19','6-21','6-22']:base['wall']=23
 if row['case']=='6-28':base['known']=[tile(x) for x in ['m1','m2','m5','m7','m7','m9','m9']]
 if row['case']=='7-1':base['wall']=40;base['draw']=tile('s6');base['known']=[tile('s1')];base['opponent_dq']=[0,2,1]
 if row['case']=='7-2' and row['variant']=='middle':base['wall']=31;base['draw']=tile('s6');base['op_melds']=[{'relative':1,'tile':tile('m7')},{'relative':1,'tile':tile('m8')},{'relative':2,'tile':tile('s1')}];base['opponent_dq']=[0,2,1]
 if row['case']=='7-2' and row['variant']=='late':base['known']=[tile('m2')]*3+[tile('m3')]*3+[tile('p6')]*3+[tile('m1')];base['wall']=19
 if row['case']=='7-3':base['known']=[tile('m1')]*4+[tile('m2'),tile('m3')]
 if row['case']=='7-4':base['known']=[tile('m2')]+[tile(x) for x in ['m1','m4'] for _ in range(2)]
 if row['case']=='7-5':base['known']=[tile('m1'),tile('m2'),tile('m3')]
 if row['case']=='7-6':base['known']=[tile('p8')]*2+[tile('p3')];base['op_meld']={'relative':1,'tile':tile('p7')}
 if row['case']=='5-13':
  for v,w,ws in [('A',35,[]),('B',23,[1]),('C',23,[1]),('D',23,[1,2])]:
   c={**base,'id':base['id']+'-'+v,'wall':w,'winners':ws}
   if v=='C':c['danger_suit']=0
   cases.append(c)
 elif row['case'] in offers and row['variant'] not in ['both','p5_claimed','p2_claimed','p6_claimed']:
  ts=offers[row['case']]
  if row['case']=='6-21':ts=[ts['ABC'.index(row['variant'])]]
  for tx in ts:
   t=tile(tx)
   if h[t]<2:continue
   cases.append({**base,'id':base['id']+'-offer-'+tx,'offered':t})
  # Own-turn fourth copy is a separate legal window.
  for t,n in enumerate(ex):
   if n==3 and h[t]==0:
    b=h[:];b[t]+=1
    cases.append({**base,'id':base['id']+'-draw-'+str(t),'hand':b,'draw':t})
    break
 else:
  if sum(base['hand'])%3==1:
   b=base['hand'][:];valid=wait(b,ex,dq)
   t=valid[0] if valid else next(t for t in range(27) if t//9!=dq and b[t]+ex[t]<4)
   b[t]+=1;base={**base,'id':base['id']+'-declared-draw','hand':b,'draw':t,'appended_draw':True}
  cases.append(base)
# Short source cores are completed with declared fixed legal melds/head so the
# transfer/extension principles also reach the real own-turn path.
for label,core,head,page in [('6-1-A1','m5','',38),('6-1-A2','m2345','',38),('6-1-A3','m2345678','',38),('6-1-B1','p23','p99',38),('6-1-B2','p23456','p99',39),('6-2-A1','m2223','',39),('6-2-A2','m2223456','',39),('6-2-B','p4445666','',39)]:
 h=[0]*27
 for group in (core+' '+head).split():
  for r in group[1:]:h[{'s':0,'p':9,'m':18}[group[0]]+int(r)-1]+=1
 target=next(t//9 for t,n in enumerate(h) if n);other=(target+1)%3;dq=(target+2)%3
 number=(13-sum(h))//3;melds=[{'type':'peng','tiles':[other*9+i]*3} for i in range(number)]
 ex=[0]*27
 for m in melds:ex[m['tiles'][0]]=3
 id='lower-core-'+label
 ws=wait(h,ex,dq)
 structures.append(dict(id=id,hand=h,melds=melds,exposed=ex,dq=dq,rows=[dict(discard=-1,waits=ws)],source_case=label,section='6.1'))
 drawn=ws[0];hh=h[:];hh[drawn]+=1
 cases.append(dict(id=id+'-declared-draw',source=id,section='6.1',page=page,hand=hh,melds=melds,exposed=ex,dq=dq,opponent_dq=[0,1,2],wall=35,draw=drawn,note='source core with explicitly constructed fixed melds/head',known=[],winners=[],appended_draw=True))

# Explicit contextual branches required by the text, kept distinct from the
# unknown complete table history.
for c in list(cases):
 if c['source']=='lower-48-6-11-base' and 'offered' not in c:
  h=c['hand'][:];h[c['draw']]-=1
  for t in [tile('p2'),tile('p8')]:cases.append({**c,'id':c['source']+'-offer-'+str(t),'hand':h,'offered':t,'draw':-1,'appended_draw':False})
 if c['source']=='lower-54-6-16-B':cases.append({**c,'id':c['id']+'-middle-pair-loss','known':c['known']+[tile('p4')],'note':'source explicitly says stop when the middle pair has a public lost copy'})
 if c['id']=='lower-85-7-6-base-offer-p9':cases.append({**c,'id':c['id']+'-root-exhausted','known':c['known']+[tile('p9')]})
 if c['id']=='lower-50-6-13-C':cases.append({**c,'id':c['id']+'-major-danger','danger_suit':0})
 if c['source']=='lower-41-6-5-B' and 'offered' not in c:
  known=[]
  for t in [tile('p3'),tile('p6'),tile('p9')]:known += [t]*(4-c['hand'][t]-c['exposed'][t])
  cases.append({**c,'id':c['id']+'-source-waits-exhausted','known':known})
 if c['source'] in ['lower-74-6-25-p5_claimed','lower-74-6-25-p2_claimed'] and 'offered' not in c:
  h=c['hand'][:];h[c['draw']]-=1
  t=tile('p2') if 'p5_claimed' in c['source'] else tile('p5')
  if h[t]>=2:
   cases.append({**c,'id':c['source']+'-second-peng','hand':h,'offered':t,'draw':-1})
   cases.append({**c,'id':c['source']+'-second-peng-public-loss','hand':h,'offered':t,'draw':-1,'known':c['known']+[t]})

# Context reversals selected for each teaching risk, not a recurring checklist.
for c in list(cases):
 if c['section'] in ['5.5','6.2','6.3','6.5.1','6.5.2','7.2'] and 'offered' not in c and c['wall']>0:
  # One publicly exhausted high-interest tile; ownership never exceeds 4.
  target=next((t for t,n in enumerate(c['hand']) if n in (1,3) and t not in c['known']),None)
  if target is not None:
   n=4-c['hand'][target]-c['exposed'][target]
   if n>0:cases.append({**c,'id':c['id']+'-public-loss','known':c['known']+[target]*n})
(D/'cases.json').write_text(json.dumps(cases,ensure_ascii=False,indent=2))
(D/'structures.json').write_text(json.dumps(structures,ensure_ascii=False,indent=2))
(D/'sections.json').write_text(json.dumps(sections,ensure_ascii=False))
print(json.dumps({'original_hands':len(source),'contexts':len(cases),'geometry_discard_states':sum(len(s['rows']) for s in structures),'sections':len(sections)}))
