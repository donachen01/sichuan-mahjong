from pathlib import Path
from functools import lru_cache
import json
D=Path(__file__).parent
@lru_cache(None)
def standard(values,melds):
 a=list(values);best=8
 def walk(start,m,t,p):
  nonlocal best
  while start<27 and not a[start]:start+=1
  if start==27:best=min(best,8-2*m-min(t,4-m)-p);return
  k=start
  if a[k]>=3:
   a[k]-=3;walk(k,m+1,t,p);a[k]+=3
  if k%9<7 and a[k+1] and a[k+2]:
   for i in [k,k+1,k+2]:a[i]-=1
   walk(k,m+1,t,p)
   for i in [k,k+1,k+2]:a[i]+=1
  if a[k]>=2:
   a[k]-=2
   if not p:walk(k,m,t,1)
   walk(k,m,t+1,p);a[k]+=2
  for delta in (1,2):
   if k%9+delta<9 and a[k+delta]:
    a[k]-=1;a[k+delta]-=1;walk(k,m,t+1,p);a[k]+=1;a[k+delta]+=1
  a[k]-=1;walk(k,m,t,p);a[k]+=1
 walk(0,melds,0,0);return best

def summary(h,ex,remaining,melds):
 st=standard(tuple(h),melds);qi=6-sum(n//2 for n in h) if melds==0 else 99;best=min(st,qi);tiles=[]
 for t,n in enumerate(remaining):
  if n<=0 or h[t]+ex[t]>=4:continue
  h[t]+=1
  nxt=min(standard(tuple(h),melds),6-sum(n//2 for n in h) if melds==0 else 99)
  h[t]-=1
  if nxt<best:tiles.append(t)
 return dict(standard=st,seven=qi if qi<99 else None,best=best,public_improving_upper=sum(remaining[t] for t in tiles),effective_tiles=tiles,meaning='structural distance and public unseen upper-bound supply; not calibrated game win rate')
refs=json.loads((D/'author-comparison.json').read_text());cases={c['id']:c for c in json.loads((D/'cases.json').read_text())};worlds=json.loads((D/'final-all-fixtures.json').read_text());out=[]
for r in refs:
 if r['author_direction_match'] is not False:continue
 c=cases[r['id']];h=c['hand'][:];ex=c['exposed'][:];rem=worlds[r['id']]['state']['Remaining18'];m=len(c['melds']);branches=[]
 if 'offered' not in c and r['action']=='Discard':
  for t in sorted(set([r['tile']]+(r['reference']['tiles'] or []))):
   if h[t]<=0:continue
   h[t]-=1;branches.append(dict(discard=t,**summary(h,ex,rem,m)));h[t]+=1
 elif 'offered' in c:
  branches.append(dict(action='Pass',**summary(h,ex,rem,m)))
  if r['action']=='Peng' and r['child']>=0:
   hp=h[:];ep=ex[:];hp[c['offered']]-=2;ep[c['offered']]+=3;hp[r['child']]-=1
   branches.append(dict(action='Peng',discard=r['child'],**summary(hp,ep,rem,m+1)))
 note='本轮选择保留当前普通胡速度/公开进张；原文清色取舍涉及的完整多轮成牌收益仍非已校准概率，不能以此证明作者错误。'
 if r['section']=='5.5':note='作者对龙七对的提价及放过普通胡更积极；本轮对当前合法听口按同口径价格和可获得性计价，取舍不同。拒绝恢复互相矛盾的续走估值来凑暗杠动作。'
 if r['id']=='lower-47-6-9-base':note='有界自摸/强制碰刻模型已纳入比较，仍未覆盖任意连续碰杠和动态换目标；当前净估计未跨过确定6底自摸及拒胡门槛。'
 if r['id']=='lower-76-6-28-base-offer-m4':note='原文明确公开损耗下，新最近路径必经仅剩1张的2万；独立逆向枚举见independent-key-bottleneck.json。保守留手，不把完整终局收益已证实作为结论。'
 if r['id']=='lower-50-6-13-B':note='原图双7，前段后文拆解出现双6，后段重复页修回双7；原图与当前整手枚举为准，未用改牌追随动作。'
 if r['id']=='lower-42-6-5-C':note='四张5条在手，必须排除第五张；同时比较根、听口上界及计分。原文理想化听面数不能直接替代当前逐听口计价。'
 out.append(dict(id=r['id'],section=r['section'],actual=r['actual'],independent_branches=branches,reason=note))
(D/'independent-difference-geometry.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
p=D/'逐例对照.md';s=p.read_text();s+='\n\n## 各项差异的独立结构和处理\n\n向听与公开有效牌上界由独立整手拆分另算；不把副本上界当牌墙概率。正式候选仍使用共享模型与各家的公开视角。\n'
for r in out:
 s+='\n### '+r['id']+'\n\n当前：'+r['actual']+'。'+r['reason']+'\n\n'
 for b in r['independent_branches']:s+='- '+str(b)+'\n'
p.write_text(s)
print('independent difference explanations',len(out),'partition states',standard.cache_info().currsize)
