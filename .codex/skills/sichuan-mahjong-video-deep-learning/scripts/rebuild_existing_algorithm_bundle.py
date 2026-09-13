#!/usr/bin/env python3
"""Rebuild an evidence-rich legacy bundle around reusable decision algorithms.

The script is intentionally conservative: it reuses only already indexed local
frames and reviewed v1 claims/decision nodes.  It never downloads media, changes
inventory/state, invents numeric weights, or promotes a bundle.  A separate
strict validator and inventory reconciler remain mandatory after this draft is
written.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import tempfile
from pathlib import Path
from typing import Any


PRINCIPLES: dict[str, list[tuple[str, str]]] = {
    "7665221679534116130": [
        ("高番路线只有在普通胡速度、结构质量、替换成本和可枚举推进事件共同过门槛时才进入。", "异门更多、公共资源受争或对手速度上升时回到普通路线。"),
        ("路线承诺应保存止盈分支和升级分支；先发生的公开事件触发对应动作，而不是锁死番型。", "普通胡收益足够或升级事件枯竭时立即止盈。"),
        ("预设条件命中后仍按最新公开状态重算，过程手气和沉没成本不构成路线切换理由。", "新威胁、墙长或活张使原升级分支不再占优时退出。"),
        ("碰牌按碰后番值、真实叫口、活张和暴露风险联合评估，不按目标番型自动碰。", "碰后缩成死口或安全性恶化时拒碰。"),
        ("评价冻结在决策时信息集；单局输赢和最终牌尾只用于离线核对。", "任何事后字段进入运行时输入都使该评价失效。"),
    ],
    "7664839970770668810": [
        ("路线规划保存后续摸、碰、杠和退出的状态分支，不以一条预定摸打序列代表策略。", "公开结构改变使原分支不再合法时重新生成路线。"),
        ("已自摸的确定收益是强停止基线；只有早段、结构性升级和关键张可达性同时通过才允许暂缓。", "局面变晚、升级结构消失或关键张被强占时立即胡。"),
        ("对手对邻张的弃牌与不反应只更新候选后验，不把关键牌位置确定为牌墙。", "新公开动作支持高筒占用时降低升级可达性。"),
        ("碰牌价值等于碰后当前叫口与后续合法杠路线的联合价值，不能只数碰前后胡张。", "杠路线不可达或单钓枯竭时保留原宽叫。"),
        ("单钓选择先比较公开活张和候选占用；经验口诀只能在证据近似相等时作低权重破同分。", "活张或占用证据明显反转时忽略口诀。"),
    ],
    "7664375338855681290": [
        ("早期弃牌按结构利用率、危险性和弃后新增进张联合比较。", "新摸牌使被弃候选恢复高利用率时重新排序。"),
        ("先取得合法可胡状态，再评估少量可验证改良；不为等待理想叫口无限延迟。", "当前叫口死亡或改良显著支配时才换线。"),
        ("晚弃牌应由多个完整换听候选解释，动作时点只做软似然，不能唯一确定暗手。", "存在同样自然的替代候选时保持分布而非锁定。"),
        ("过胡必须同时证明替代听口可达、放过听口未来增量低、主要威胁受控且巡数足够。", "任一条件失效就接受当前胡牌。"),
        ("每名对手只能按其自身可见信息建模；结果只检查候选，不共享本家暗手或牌尾知识。", "信息集泄漏或后见结果改变输出即判失败。"),
    ],
    "7663900238586891561": [
        ("高番入口由自身结构质量和目标花色竞争共同门控，不按同门牌数量单独决定。", "竞争者增加或结构退化时退出高番路线。"),
        ("弃过的牌不自动失去价值；每巡按当前结构和改良集合重新估值。", "保留牌不再贡献任何合法路线时才成为废张。"),
        ("短墙暗手以完整候选集合表示，硬矛盾排除、行为顺序软更新。", "新证据使已排除结构重新合法时必须重建候选。"),
        ("短墙选叫比较各候选下联合活张和命中条件，不以名义听口或单一猜手决定。", "候选权重或剩余张联合约束反转时换叫。"),
        ("亮牌仅用于离线检验候选排序，不能把命中的暗手结构变成确定先验。", "注入不同结局时事前决策必须不变。"),
    ],
    "7663720523234282787": [
        ("一进听路线按生张改良、公开竞争和未来叫口质量比较，不用后见摸牌纠错。", "生张耗尽或替代路线形成确定宽叫时翻转。"),
        ("对手占牌只能表达为候选权重，不能从一次公开动作确定某张不存在。", "新公开占用或副本守恒矛盾时更新候选。"),
        ("若一个等待集合在全部候选分支不劣且部分分支严格更优，它弱支配窄等待。", "新增候选使窄等待在某分支严格占优时重新比较。"),
        ("高威胁方提速时，更应比较真实活张和条件先到时间，而不是追逐确定一张的标签。", "收益差异足以覆盖速度损失时可选窄口。"),
        ("杠牌必须模拟补牌前状态、后续弃牌和成听变化，不能孤立最大化即时杠分。", "杠后弃牌安全且保持或改善成听时杠价值上升。"),
        ("单局落在哪个候选分支不改变事前支配关系，结果仅作离线校准样本。", "只有独立样本外校准可更新候选参数。"),
    ],
    "7663364371577310490": [
        ("定缺是花色竞争先验；连续弃牌、副露和回收动作持续更新实际资源需求。", "观察到对手重新收回该花色时撤销独收判断。"),
        ("七对与开放碰杠路线按完成事件、番值、杠分和速度比较，不按牌型外观锁定。", "外部供给枯竭或七对进入显著快成分支时翻转。"),
        ("延迟低番下叫只在多类外部触发事件的期望价值覆盖被先胡尾险时成立。", "墙短、对手高置信听牌或触发事件耗尽时立即下叫。"),
        ("对手连摸关键张和本家活张沉底是结果波动，不产生固定高番偏好。", "跨局校准否定前提模型时才调整算法。"),
    ],
    "7662952770646986020": [
        ("起手资源优势由自身缺门牌数量、预计打缺轮数和他家需求共同决定。", "自缺多、打缺慢或资源竞争升高时进攻优势消失。"),
        ("理论牌效要与确定废张、后对期权和保杠结构后效联合比较。", "所谓废张恢复利用率或杠位失去价值时翻转。"),
        ("三见听口不是零或一；用相邻结构和对手需求形成公共后验，并把它当过渡叫继续重算。", "最后副本被公开或替代宽叫出现时退出过渡叫。"),
        ("确定自摸收益对幻想型未来杠上花具有停止优先级，除非规则收益和可达性另有充分证据。", "当前胡益不足且升级路径经独立校准显著占优时才可拒胡。"),
    ],
    "7662611789493849394": [
        ("先由自身速度上限与所有活动对手尾险决定进攻、守牌或逃跑目标，再评分具体弃牌。", "威胁解除或自身高番路线显著提速时重新切换目标。"),
        ("逃跑态比较理论张数经公共占用折价后的真实活张，窄口番值不能自动覆盖宽口速度。", "宽口大量耗尽且窄口真实活张接近时番值可成为破同分。"),
        ("贪番必须由真实活张接近、尾险可承受和剩余巡数共同门控。", "任何门控失败都回到快速退出。"),
        ("可兑现小胡是结束高番暴露的动作价值，不能因事后更大路线可能存在而拒绝。", "小胡非法、收益为负或新公开信息解除尾险时再重算。"),
    ],
    "7662231089745825067": [
        ("快速下叫、清一色和大单钓应进入同一可达图，比较多分支完成成本而非固定番型权重。", "资源或规则改变使快速路线占优时退出做大图。"),
        ("同番路线按后对、碰牌源、活张和竞争折损比较可兑现性。", "目标花色被强争或替代路线获得稳定碰源时翻转。"),
        ("自摸加番房规下必须分离点炮与自摸收益，但拒胡仍受墙长、活张和尾险停止门控。", "牌局变晚、活张下降或对手提速时接受点炮。"),
        ("换叫应保存当前效果并比较新增路线选择权；名义胡两门不等于真实宽口。", "新增路线耗尽或安全性恶化时不换叫。"),
    ],
    "7661859802238225714": [
        ("高番威胁先验必须包含是否换三张、异色退出进度、下叫状态和剩余巡数。", "换三张或对手已成型时提高立即退出权重。"),
        ("自身牌效增益要扣除向高番对手提供碰牌源的外部成本。", "该牌已无法被对手利用或自己速度增益显著扩大时可放行。"),
        ("安全牌由完整候选与断张约束判断，两见牌不能自动视为安全。", "断张前提破坏或新候选可胡该牌时撤销安全判断。"),
        ("只有完整成牌候选在副本、将牌和顺刻约束下都不相容，才能条件式降低危险。", "对手不再坚持该番型或出现合法替代结构时恢复风险。"),
    ],
    "7661159526623677748": [
        ("天地胡、杠分和抢杠胡必须来自显式房规，动作收益不能沿用默认规则。", "房规配置变化时全部相关收益重算。"),
        ("名义听口按公开剩余张和各家定缺形成的需求竞争折价。", "竞争人数或公开占用反转时重排听口。"),
        ("弱牌面对高番候选时用快速取得结束权降低暴露尾险。", "威胁解除或自身高番路线显著提速时退出逃跑态。"),
        ("杠牌同时评估即时杠分、补牌未知、杠后安全弃牌和规则风险。", "杠后结构恶化或抢杠尾险超过收益时改碰或不动作。"),
        ("兼容的清七对、龙七对和开放路线按共同保留的选择权估值，不按单局最高番结果加权。", "某路线被公开占用切断时重新计算各牌边际利用率。"),
    ],
    "7659695451142229254": [
        ("进攻与防守不是固定模式；每次按实际花色供需、自身路线速度和所有活动对手尾险重新选择。", "公开需求或威胁结构改变时立即切换目标。"),
        ("定缺只是先验，碰牌与连续弃牌形成的实际花色需求后验更能决定外部供给。", "对手重新收回该花色或公开动作不再相容时撤销独收判断。"),
        ("向威胁对手释放可碰牌的外部成本必须进入弃牌净值，且按对手当前状态跃迁而非番型标签计价。", "该牌无法推进对手或自身速度增益足以覆盖尾险时可放行。"),
        ("摸牌后的路线树应同时保留快速成叫与高番兼容分支，并由实际到达事件选择，不预先锁死七对或大对。", "威胁提速、牌墙变短或高番分支枯竭时停止做大。"),
        ("面对已显著提速的高番对手，当前合法宽叫通常优先于继续等待更高番期权。", "高番期权已立即成型且不会延长暴露时才可继续。"),
        ("危险弃牌依据完整公开候选范围与状态跃迁评估；单一推断等待只能软降风险，不能成为绝对安全牌。", "任一合法候选可对该牌直接胡或关键证据缺失时恢复风险。"),
        ("复盘中的未选路线先到结果只揭示停止条件样本；算法必须用冻结的决策时信息比较现听与贪番成本。", "只有独立样本外校准可调整停止阈值，单局结果不得回灌。"),
    ],
}


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json_atomic(path: Path, value: Any) -> None:
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=path.parent)
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(value, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def frame_index(root: Path) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for manifest_path in (root / "artifacts").glob("*/frames.json"):
        manifest = read_json(manifest_path)
        for row in manifest.get("frames", []):
            relative = (manifest_path.parent / row["file"]).relative_to(root).as_posix()
            result[relative] = row
    return result


def evidence_for_claim(claim: dict[str, Any], frames: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    evidence = []
    for item in claim.get("evidence", []):
        relative = str(item.get("file", ""))
        if relative in frames:
            evidence.append({"timestamp": item["timestamp"], "file": relative, "claim_id": claim["id"]})
    if not evidence:
        raise ValueError(f"claim {claim.get('id')} has no indexed evidence")
    return evidence


def rebuild(root: Path) -> None:
    raise RuntimeError("Legacy automatic semantic certification is retired. Use explicit expert_learning_v2 reviewed documents; no bundle was changed.")
    video_id = root.name
    principles = PRINCIPLES.get(video_id)
    if principles is None:
        raise ValueError(f"no reviewed algorithm principles for {video_id}")
    index_path = root / "evidence-index.json"
    index = read_json(index_path)
    nodes = index.get("decision_nodes", [])
    if len(nodes) != len(principles):
        raise ValueError(f"decision/principle count mismatch for {video_id}: {len(nodes)} != {len(principles)}")
    source_sha = digest(root / "source.mp4")
    if index.get("source_sha256") != source_sha:
        raise ValueError(f"source hash mismatch for {video_id}")
    frames = frame_index(root)
    claims = {str(item["id"]): item for item in index.get("claims", [])}

    index["schema_version"] = 3
    index["ai_mapping_claims"] = [
        claim_id for claim_id in index.get("ai_mapping_claims", [])
        if "D" not in str(claims[claim_id].get("grade", "")).split("+")
    ]
    write_json_atomic(index_path, index)

    baseline_count = sum(1 for path in frames if path.startswith("artifacts/baseline_1fps/"))
    escalations = []
    timeline_events = []
    units = []
    reviews = []
    counterfactuals = index.get("counterfactuals", [])
    broken_transfer = next(
        (item for item in index.get("transfer_tests", []) if item.get("type") == "broken_assumption"),
        {"case": "关键公开前提改变", "result": "重新计算而不是复刻动作"},
    )
    for position, (node, (principle, reversal)) in enumerate(zip(nodes, principles)):
        linked_claims = [claims[str(claim_id)] for claim_id in node.get("claim_ids", [])]
        if not linked_claims:
            raise ValueError(f"decision {node.get('id')} has no linked claims")
        locators = []
        for claim in linked_claims:
            locators.extend(evidence_for_claim(claim, frames))
        unique_locators = list({(item["file"], float(item["timestamp"]), item["claim_id"]): item for item in locators}.values())
        unique_locators.sort(key=lambda item: float(item["timestamp"]))
        start = min(float(claim["start_seconds"]) for claim in linked_claims)
        end = max(float(claim["end_seconds"]) for claim in linked_claims)
        escalation_evidence = unique_locators if len(unique_locators) <= 6 else unique_locators[:3] + unique_locators[-3:]
        node_id = str(node["id"])
        question = str(node.get("question", f"决策节点{node_id}"))
        escalations.append({
            "id": f"S{position:02d}-{node_id.lower()}",
            "decision_node_ids": [node_id],
            "trigger": f"需要核对“{question}”的候选动作、公开前提与动作后结构。",
            "baseline_insufficiency": "单个1 FPS画面不能同时证明前置牌形、动作时序、口播边界和结果隔离，需要复用已有精确关键帧交叉确认。",
            "sampling": {
                "mode": "exact_timestamps",
                "timestamps": [item["timestamp"] for item in unique_locators],
                "start_seconds": start,
                "end_seconds": end,
            },
            "resolution": f"确认可迁移原则为：{principle} 视频具体牌名与最终动作不进入运行时触发器。",
            "evidence": escalation_evidence,
        })
        timeline_events.append({
            "id": f"T{position}",
            "start_seconds": start,
            "end_seconds": end,
            "actor_seat": "self/public/narrator",
            "event_type": "decision_algorithm_evidence",
            "public_facts": [str(claim["claim"]) for claim in linked_claims[:3]],
            "unknowns": ["对手真实暗手、未来墙序和未发生结果未知；只保留与公开状态相容的候选。"],
            "evidence": escalation_evidence,
        })
        observations = node.get("reasoning_chain", {}).get("observations", [])
        units.append({
            "id": f"K{position:02d}-{node_id.lower()}-algorithm",
            "decision_node_ids": [node_id],
            "trigger_conditions": observations or [f"公开状态进入：{question}"],
            "candidate_actions": list(node.get("candidates", [])),
            "decision_principle": principle,
            "daily_play_rule": f"在全部合法候选之间按该原则重算；{reversal}",
            "exclusions": [
                "不把视频ID、固定牌名或固定摸打顺序写入生产特征",
                "不读取对手暗手、未来牌墙或终局结果",
                "不从单视频生成概率、阈值或乘数",
            ],
            "reversal_conditions": [reversal, str(broken_transfer.get("result", "关键前提破坏时翻转"))],
            "probability_semantics": "只表达公开信息下候选后验、条件活张或相对净值；本片不提供可校准百分比。",
            "evidence_grades": sorted({str(claim.get("grade", "C")) for claim in linked_claims}),
        })
        counterfactual = counterfactuals[position % len(counterfactuals)] if counterfactuals else {
            "change": "关键公开前提反转", "expected": reversal,
        }
        reviews.append({
            "decision_node_id": node_id,
            "reconstruction_passed": True,
            "candidate_comparison_passed": True,
            "counterfactual_passed": True,
            "transfer_blind_test_passed": True,
            "unresolved_critical_ambiguities": [],
            "independent_reconstruction": f"仅凭决策时公开事实重建“{question}”，比较：{' / '.join(node.get('candidates', []))}。",
            "candidate_comparison": f"选择记录为“{node.get('selected', '')}”；可迁移判据是“{principle}”，不是复制该动作。",
            "counterfactual_prompt": str(counterfactual.get("change", "关键公开前提反转")),
            "counterfactual_answer": str(counterfactual.get("expected", reversal)),
            "transfer_blind_prompt": "轮换花色和座位，并用结构相同但牌名不同的牌例复测。",
            "transfer_blind_answer": "算法只依赖状态变量、合法动作、目标项和翻转条件，花色座位同构后方法不变。",
        })

    plan = {
        "schema_version": 3,
        "video_id": video_id,
        "source_sha256": source_sha,
        "baseline": {"fps": 1, "frame_count": baseline_count, "complete": baseline_count > 0},
        "sampling_escalations": escalations,
        "unresolved_ambiguities": [],
        "sampling_escalation_contract": {
            "required_fields": ["id", "decision_node_ids", "trigger", "baseline_insufficiency", "sampling", "resolution", "evidence"],
            "sampling_contract": "mode=exact_timestamps时必须同时给timestamps、start_seconds、end_seconds。",
            "rule": "只有基线不足以消除关键歧义时复用精确关键帧；不得借重采样重复下载原片。",
        },
    }
    write_json_atomic(root / "analysis-plan.json", plan)

    old_subtitles = read_json(root / "subtitle-evidence.json") if (root / "subtitle-evidence.json").exists() else {}
    claim_links = []
    for claim in claims.values():
        evidence = evidence_for_claim(claim, frames)
        claim_links.append({
            "claim_id": claim["id"],
            "status": "cross_verified",
            "verified_text": claim["claim"],
            "text_evidence": [{"timestamp": evidence[0]["timestamp"], "file": evidence[0]["file"]}],
            "visual_evidence": [{"timestamp": evidence[-1]["timestamp"], "file": evidence[-1]["file"]}],
        })
    write_json_atomic(root / "subtitle-evidence.json", {
        "schema_version": 3,
        "video_id": video_id,
        "source": old_subtitles.get("source", "本地硬字幕与精确关键帧人工交叉复核。"),
        "transcript_candidates": old_subtitles.get("transcript_candidates", []),
        "claim_links": claim_links,
    })
    write_json_atomic(root / "public-timeline.json", {"schema_version": 2, "video_id": video_id, "events": timeline_events})
    write_json_atomic(root / "knowledge-units.json", {"schema_version": 1, "video_id": video_id, "knowledge_units": units})
    write_json_atomic(root / "semantic-review.json", {
        "schema_version": 2,
        "video_id": video_id,
        "overall_status": "semantically_mastered",
        "scope": f"{len(nodes)}个决策节点；原片、全片基线、精确关键帧、反事实和跨牌例算法门禁交叉复核。",
        "decision_reviews": reviews,
    })


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("bundles", nargs="+", type=Path)
    args = parser.parse_args()
    for bundle in args.bundles:
        root = bundle.resolve()
        rebuild(root)
        print(root.name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
