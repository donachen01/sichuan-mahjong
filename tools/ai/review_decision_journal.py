#!/usr/bin/env python3
"""Render an existing native audit journal; never changes live AI parameters."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('journal', type=Path)
parser.add_argument('--output', type=Path)
args = parser.parse_args()
traces, rounds, errors = {}, {}, []
for number, line in enumerate(args.journal.read_text().splitlines(), 1):
    if not line.strip():
        continue
    try:
        entry = json.loads(line)
        for field in ('snapshotsBefore', 'snapshotsAfter'):
            snapshots = json.loads(entry.get(field, '[]'))
            if not isinstance(snapshots, list):
                errors.append(f'记录 {number}：观察快照不可用')
                continue
            for snapshot in snapshots:
                identity = (snapshot['RoundId'], snapshot['Seat'])
                rounds[identity] = snapshot
                for trace in snapshot.get('Decisions', []):
                    traces[trace['Id']] = (identity, trace)
    except (ValueError, KeyError, TypeError) as error:
        errors.append(f'记录 {number}：损坏或格式不匹配（{error}）')
lines = ['# AI 决策复盘', '',
         '这份报告只使用决策当时保存的信息与后续实际观察。后续得失不等于单步因果收益，候选估值也不等于已验证的真实胜率。', '',
         f'共 {len(rounds)} 个座位局记录、{len(traces)} 次决策。', '']
for identity, snapshot in rounds.items():
    lines += [f'## 局 {identity[0]} · 座位 {identity[1]}', '']
    for key, (owner, trace) in traces.items():
        if owner != identity:
            continue
        lines += [f'### 观察 {trace["ViewVersion"]}：{trace["Action"]} / 牌型编号 {trace["Tile"]}', '',
                  f'- 决策编号：`{key}`',
                  f'- 当时计划：{trace["PrimaryRoute"]}；备用：{trace["FallbackRoute"]}',
                  f'- 执行状态：{trace["Status"]}；确认事件：{trace.get("ExecutionEvent")}',
                  f'- 后续累计积分变化：{trace.get("ScoreDeltaSinceDecision")}；已观察到自家胡牌：{trace.get("OwnWinObserved", False)}',
                  f'- 后续路线：{trace.get("LatestRoute", "")}；结构距离：{trace.get("LatestBestDistance")}', '',
                  '当时依据：', '']
        lines += [f'- {reason}' for reason in dict.fromkeys(trace['PlanEvidence'] + trace['Reasons'])]
        lines += ['', '| 候选 | 选择分（仅同次比较） | 评分单位 | 模型估值 | 准入 |', '|---|---:|---|---:|---|']
        for candidate in trace['Candidates']:
            lines.append(f'| {candidate["Action"]}/{candidate["Tile"]} | {candidate["SelectionScore"]} | {candidate["ScoreUnit"]} | {candidate.get("ModeledNet")} | {candidate.get("Admissible")} |')
        lines += ['']
if errors:
    lines += ['## 记录缺口', ''] + ['- ' + error for error in errors]
output = args.output or args.journal.with_suffix('.review.md')
output.write_text('\n'.join(lines) + '\n')
print(f'{output}: {len(traces)} decisions, {len(errors)} recording gaps')
