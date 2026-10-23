# coding: utf-8
from pathlib import Path
import json
D=Path(__file__).parent
cases={x['id']:x for x in json.loads((D/'cases.json').read_text())}
ref={}
def add(id,actions,tiles=None,children=None,note='原文方向；未知完整历史为声明的兼容背景'):
 ref[id]=dict(actions=actions,tiles=tiles,children=children,note=note)
b='lower-36-'
add(b+'5-12-base',['Discard'],[13]);add(b+'5-13-base-A',['an_gang'],[19])
for v in 'BD':add(b+'5-13-base-'+v,['Discard'],[12,14])
add(b+'5-14-base',['Discard']);add(b+'5-15-base',['Discard'],[0])
add('lower-41-6-4-base',['Hu']);add('lower-41-6-5-A',['Discard'],[16]);add('lower-41-6-5-B',['Discard'],[9,11,16],note='原文列举不同供给下的1/3/8筒取舍，不声称唯一答案')
add('lower-42-6-5-C',['Discard'],[1]);add('lower-42-6-5-D',['Discard'],[2,6])
add('lower-44-6-6-B',['Discard'],[12,13,15,17],note='清理异门，具体首打由当前普通胡退路比较')
add('lower-47-6-8-B',['Discard'],[10]);add('lower-47-6-9-base',['Discard'],[15]);add('lower-47-6-10-base',['Hu'])
add('lower-48-6-11-base-declared-draw',['Hu'],note='构造摸2筒，原文明确自摸2/8筒应胡')
add('lower-48-6-11-base-offer-10',['Peng'],children=[23,25])
add('lower-49-6-12-A',['Discard'],[22]);
for v in 'BC':add('lower-49-6-12-'+v,['Discard'],[1,3])
add('lower-50-6-13-A',['Discard'],[1]);add('lower-50-6-13-B',['Discard'],[0],note='原图双7，后文拆解双6；原图保留，原文动作仅作参考')
for v in 'CD':add('lower-50-6-13-'+v,['Discard'],[10,11,15,16])
for v in 'ABDE':add('lower-51-6-14-'+v,['Discard'],[11,12],note='中性无明显危险背景下进攻/兼顾清色')
add('lower-53-6-15-A',['Discard'],[15]);add('lower-53-6-15-B',['Discard'],[19])
add('lower-54-6-16-A',['Discard'],[19,20]);add('lower-54-6-16-C',['Discard'],[20]);add('lower-55-6-16-D',['Discard'],[20])
add('lower-54-6-16-B-middle-pair-loss',['Discard'],[9],note='原文明确中张对子见一张时退出清色')
for v in 'AC':add('lower-55-6-17-'+v,['Discard'],list(range(9,18)))
add('lower-55-6-17-B',['Discard'],[19]);add('lower-56-6-18-A',['Discard'],[11]);add('lower-56-6-18-B',['Discard'],[0]);add('lower-57-6-18-C',['Discard'],list(range(9,18)))
for v in 'AB':add('lower-67-6-19-'+v,['Discard'])
add('lower-68-6-19-C',['add_gang'],[12])
for v in 'ABC':add('lower-68-6-20-'+v,['Discard'])
add('lower-68-6-20-D',['add_gang'],[5])
add('lower-69-6-21-A-offer-m2',['Gang'],[19]);add('lower-69-6-21-B-offer-m3',['Peng'],[20],[23]);add('lower-69-6-21-C-offer-m3',['Peng'],[20],[23],note='当前4番封顶，对照作者4番分支')
add('lower-70-6-22-A',['Discard'],[16]);add('lower-70-6-22-B',['an_gang'],[19])
add('lower-72-6-23-base-offer-m4',['Pass'])
for page,v in [(72,'A'),(73,'B')]:add(f'lower-{page}-6-24-{v}-offer-p3',['Peng'],children=[4,5])
add('lower-73-6-24-C-offer-p3',['Pass'])
for t in ['p2',
'p5',
'p9']:add('lower-73-6-25-base-offer-'+t,['Peng'],children=[6,7])
for name in ['p5_claimed',
'p2_claimed']:
 add('lower-74-6-25-'+name+'-second-peng',['Peng'],children=[7],note='相关关键张无额外公开损耗的第二次碰')
 add('lower-74-6-25-'+name+'-second-peng-public-loss',['Pass'],note='当前这张碰牌已多见一张，碰后另一个关键张只剩最后一张')
add('lower-75-6-26-base-offer-p3',['Pass'])
for t in ['p4',
'p5',
'p7']:add('lower-75-6-26-base-offer-'+t,['Peng'],children=[6,7])
add('lower-75-6-27-base-offer-p3',['Pass'])
for t in ['p6',
'p8']:add('lower-75-6-27-base-offer-'+t,['Peng'],children=[22,23])
for t in ['m2',
'm4']:add('lower-76-6-28-base-offer-'+t,['Peng'],children=[5,7])
add('lower-76-6-28-base-draw-25',['add_gang'],[25]);add('lower-78-7-1-base',['Discard'],[0]);add('lower-81-7-2-late',['Discard'],[16]);add('lower-85-7-6-base-offer-p9',['Peng'],children=[11]);add('lower-85-7-6-base-offer-p9-root-exhausted',['Hu'],note='最后根听已耗尽的边界，不是另一本书原例答案')
def label(t):return str(t%9+1)+'条筒万'[t//9] if 0<=t<27 else '—'
def describe(r):
 a={'Discard':'打',
'Hu':'胡',
'Peng':'碰',
'Gang':'明杠',
'an_gang':'暗杠',
'add_gang':'补杠',
'Pass':'过'}[r['action']]
 return a+(label(r['tile']) if r['action'] not in ['Hu',
'Pass'] else '')+((' → 打'+label(r['child'])) if r['action']=='Peng' and r['child']>=0 else '')
a=json.loads((D/'final-all.json').read_text());rows=[]
for r in a['rows']:
 x=ref.get(r['id']);match=None
 if x:
  match=r['action'] in x['actions'] and (x['tiles'] is None or r['tile'] in x['tiles']) and (x['children'] is None or r['child'] in x['children'])
 rows.append(dict(id=r['id'],source=cases[r['id']]['source'],section=cases[r['id']]['section'],actual=describe(r),reference=x,author_direction_match=match,action=r['action'],tile=r['tile'],child=r['child']))
(D/'author-comparison.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
comp=[r for r in rows if r['reference']];diff=[r for r in comp if not r['author_direction_match']]
text=[
'# 下部逐例方向对照',
'[逐节结论](逐节学习与算法.md) · [执行结果](执行结果.md)',
f'本轮{len(rows)}个具体背景。{len(comp)}个有明确原文或本轮边界方向的背景中，{sum(r["author_direction_match"] for r in comp)}个满足方向，{len(diff)}个保留差异。其余是理论结构、声明摸牌、普通退路或公开损耗变体，不虚构作者答案。这个比例不是棋力、原局复现率或独立样本成功率。',
'## 差异的处理原则',
'本轮不以改手牌、捏造牌河、固定奖励或读取对手暗手凑动作。共同规则、实体和执行错误已修复；缺少原局全部历史的状态只能作有边界的对照。模型策略与作者仍不同时，说明取舍、条件及模型局限，不宣布作者错误。',
'5.5的5-12/5-15：作者愿意保留龙七对并放掉较低价来牌；本轮有限共同模型对多种当前合法来牌做计价，仍可能选择更易兑现的普通/七对口。5-13A在同口径后手比较后也可能保持龙七对，不能为保留旧暗杠结果恢复不一致的估值公式。',
'6-9：新增解析模型已把本家进张与对手强制供出的刻子第四张分开并互斥计入；但不包含任意连续碰杠及动态换目标。当前控制背景的保守净值仍不足以放弃6底确定自摸，保留胡。这证明条件计算已接入，不证明作者放飞错误或长期收益已校准。',
'6.4部分差异：原书未给定全部公示损耗及危险信号；采用可核验的互斥整手、公开供给与当前普通胡退路。6-13B原图与后文拆分存在实体差异；不将作者笔误的拆分强行作为生产前提。',
'6-28碰4万：独立逆向枚举发现，在原文列出的可见1/2/5/7/7/9/9万前提下，碰4后最近的两张成胡路径都必须再取得最后1张2万；碰前最近3张的路径有16种，交集为空。见`independent-key-bottleneck.json`。这支持保守保留灵活度，但不是完整终局净收益证明。',
'源牌面、共同模型有限范围、未知历史、规则差异和真实执行分别记载，不能把“指令执行一致”冒充“所有作者动作一致”。',
'## 全部背景',
'|背景|小节|正式选择|原文/边界方向对照|',
'|---|---|---|---|']
for r in rows:
 if not r['reference']:status='结构/构造变体；无唯一作者动作断言'
 else:status=('一致' if r['author_direction_match'] else '**差异保留**')+'；'+r['reference']['note']
 text.append('|'+r['id']+'|'+r['section']+'|'+r['actual']+'|'+status+'|')
(D/'逐例对照.md').write_text('\n\n'.join(text[:15])+'\n'+ '\n'.join(text[15:])+'\n')
print(json.dumps({'contexts':len(rows),'reference_contexts':len(comp),'matches':sum(r['author_direction_match'] for r in comp),'differences':len(diff),'difference_ids':[r['id'] for r in diff]},ensure_ascii=False))
