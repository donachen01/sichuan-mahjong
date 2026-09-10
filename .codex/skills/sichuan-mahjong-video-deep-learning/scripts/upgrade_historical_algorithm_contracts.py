#!/usr/bin/env python3
"""Upgrade reviewed historical bundles to the algorithm-abstraction schema.

This helper writes semantic/AI *drafts* only.  It never changes inventory or
learning-state status; promotion still requires a fresh strict validator pass.
The caller must provide an explicit list of bundle directories and a reviewed
specification below must exist for every requested video.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


COMMON_OUTCOME_ARTIFACT = (
    "research/xiaolaoshi_deep_learning/7665945910290959651/algorithm-reaudit-runtime.json"
)
COMMON_OUTCOME_CASE = "D04-success-outcome-does-not-calibrate-route"
HISTORICAL_SHARED_ARTIFACT = "research/xiaolaoshi_deep_learning/historical-algorithm-reaudit-20260902.json"
HISTORICAL_SHARED_COMMAND = (
    "dotnet build research/xiaolaoshi_deep_learning/local_video_checks/LocalVideoChecks.csproj --no-restore && "
    "dotnet run --project research/xiaolaoshi_deep_learning/local_video_checks/LocalVideoChecks.csproj --no-build -- "
    "research/xiaolaoshi_deep_learning/local_video_checks/historical-algorithm-reaudit-20260902-input.json "
    "research/xiaolaoshi_deep_learning/historical-algorithm-reaudit-20260902.json"
)
DEFAULT_COMPONENTS = [
    "dotnet/AI.Core/Entry/SichuanAiFacade.cs",
    "dotnet/AI.Core/Engines/SichuanShantenEngine.cs",
    "dotnet/AI.Core/Engines/SichuanUkeireEngine.cs",
    "dotnet/AI.Core/Engines/SichuanBeliefEngine.cs",
    "dotnet/AI.Core/Engines/SichuanOpponentRangeEngine.cs",
    "dotnet/AI.Core/Engines/SichuanWallAvailabilityEngine.cs",
    "dotnet/AI.Core/Decision/SichuanUnifiedDecisionEngine.cs",
    "dotnet/AI.Core/Search/SichuanActionTransitionEngine.cs",
]


SPECS: dict[str, dict[str, Any]] = {
    "7669673553574235411": {
        "order": 27,
        "family": "副露与杠牌动作转移",
        "state": ["自身手牌结构", "碰杠前后副露数", "公共墙后验", "动作发生顺序", "补牌尚未发生的状态"],
        "objectives": ["向听", "可达改良张", "副露后的路线价值", "杠分与结构风险", "选择权价值"],
        "status": "validated_existing_algorithm",
        "tests": {
            "suit_rotation": "D07-mirror-suit-transfer",
            "structural_variant": "D01-synthetic-peng7",
            "broken_assumption": "D02-dead-wait",
            "outcome_invariance": "D07-gang2-before-supplement",
        },
    },
    "7669300086995733760": {
        "order": 28,
        "family": "路线选择、公共证据与牌副本守恒",
        "state": ["自身路线候选", "活动玩家竞争", "公开碰弃事件", "公共墙后验", "精确规则与番值"],
        "objectives": ["路线完成率", "预期番值", "公开风险", "资源可达性", "规则结算净分"],
        "status": "extended_shared_algorithm",
        "tests": {
            "suit_rotation": "D06-reflect-and-suit-transfer",
            "structural_variant": "D01-conditional-flush-competition",
            "broken_assumption": "D04-four-seen-no-live-wait",
            "outcome_invariance": COMMON_OUTCOME_CASE,
        },
    },
    "7668923971722612019": {
        "order": 29,
        "family": "精确牌效、软证据与沉没成本隔离",
        "state": ["自身精确向听与改良集合", "公开无反应证据", "公共墙后验", "活动玩家集合", "当前可兑现收益"],
        "objectives": ["成牌速度", "预期胡益", "点炮与查叫风险", "未来路线价值", "当前增量净分"],
        "status": "validated_existing_algorithm",
        "tests": {
            "suit_rotation": "D06-mirrored-suit",
            "structural_variant": "D03-draw8p",
            "broken_assumption": "D06-dead-14p",
            "outcome_invariance": "D07-score-offset-not-chase-loss",
        },
    },
    "7668557689722572086": {
        "order": 30,
        "family": "清色动态路线与胡碰联合候选",
        "state": ["自身路线宽度", "公共墙后验", "胡碰杠合法候选", "碰后真实弃牌", "活动付款人数与规则番值"],
        "objectives": ["即时胡益", "碰后持续收益", "路线完成率", "弃牌与过胡成本", "风险调整后净分"],
        "status": "extended_shared_algorithm",
        "tests": {
            "suit_rotation": "D03-public-wide-suit-transfer",
            "structural_variant": "D03-public-wide-claim-control",
            "broken_assumption": "D03-joint-dead-expanded-waits",
            "outcome_invariance": "D03-D05-frozen-score-and-payers",
        },
    },
    "7668166538091842842": {
        "order": 31,
        "family": "硬合法性、共享未知池与等待支配",
        "state": ["定缺与退出硬约束", "共享未知牌副本池", "完整候选暗手", "候选等待集合", "公共墙后验"],
        "objectives": ["合法候选覆盖", "等待可达性", "候选后验校准", "风险排序", "先到概率"],
        "status": "extended_shared_algorithm",
        "tests": {
            "suit_rotation": "D03-reflect-suit-mirror",
            "structural_variant": "D03-joint-capacity-not-independent",
            "broken_assumption": "D01-missing-suit-no-hu-threat-8s",
            "outcome_invariance": COMMON_OUTCOME_CASE,
        },
    },
    "7667803347944033570": {
        "order": 32,
        "family": "碰杠时序、机会成本与工程结算",
        "state": ["碰杠前后手牌", "补牌是否发生", "公共墙后验", "当前听口与间接改良", "杠分及呼叫转移规则"],
        "objectives": ["动作后向听", "可达改良张", "即时杠分", "路线机会成本", "最终规则净分"],
        "status": "validated_existing_algorithm",
        "tests": {
            "suit_rotation": "D04-mirror-absorb9s",
            "structural_variant": "D02-real-transition-not-free-ready",
            "broken_assumption": "D03-dead3-not-call",
            "outcome_invariance": "D02-gang8-before-draw",
        },
    },
    "7667443577554832680": {
        "order": 33,
        "family": "短墙多人事件模拟与末巡净分",
        "state": ["精确叫口", "短墙长度", "共享隐藏池粒子", "活动玩家合法动作", "多人胡杠与流局规则"],
        "objectives": ["多人期望净分", "点炮与自摸收益", "杠后事件价值", "查叫花猪结算", "尾部风险"],
        "status": "extended_shared_algorithm",
        "tests": {
            "suit_rotation": "D04-real-facade-suit-reflection",
            "structural_variant": "D04-real-facade-triplet2",
            "broken_assumption": "D03-locked-or-incomplete-state-not-overridden",
            "outcome_invariance": "D02-gang6-before-replacement",
        },
    },
    "7667063064524574015": {
        "order": 34,
        "family": "单行道供给、胡过停止与动态重算",
        "state": ["自身精确叫口", "公共墙后验", "活动付款人数", "对手公开需求", "胡过锁与碰杠后结构"],
        "objectives": ["即时胡益", "未来自摸与点炮收益", "路线完成率", "过胡成本", "新增动作后的净分"],
        "status": "extended_shared_algorithm",
        "tests": {
            "suit_rotation": "D02-public-posterior-reachability-is-suit-invariant",
            "structural_variant": "D03-real-early-single-lane-pass-hu",
            "broken_assumption": "D03-late-or-dead-waits-take-hu",
            "outcome_invariance": COMMON_OUTCOME_CASE,
        },
    },
}


def historical_spec(
    order: int,
    family: str,
    state: list[str],
    objectives: list[str],
    tests: tuple[str, str, str, str],
    *,
    status: str = "validated_existing_algorithm",
    behavior: str = "",
    focus_artifact: str | None = None,
    focus_command: str | None = None,
) -> dict[str, Any]:
    return {
        "order": order,
        "family": family,
        "state": state,
        "objectives": objectives,
        "status": status,
        "behavior": behavior,
        "generalization_artifact": HISTORICAL_SHARED_ARTIFACT,
        "focus_artifact": focus_artifact or HISTORICAL_SHARED_ARTIFACT,
        "focus_command": focus_command or HISTORICAL_SHARED_COMMAND,
        "tests": dict(zip(
            ["suit_rotation", "structural_variant", "broken_assumption", "outcome_invariance"],
            tests,
        )),
    }


INFERENCE_TESTS = (
    "D03-generic-public-action-compatibility-rotates-and-reverses",
    "D02-no-response-soft-not-impossible",
    "D01-D02-public-demand-not-hidden-certainty",
    COMMON_OUTCOME_CASE,
)
ROUTE_TESTS = (
    "D02-public-posterior-reachability-is-suit-invariant",
    "D00-D01-qing-entry-and-dynamic-competition",
    "D01-public-competition",
    COMMON_OUTCOME_CASE,
)
HU_PASS_TESTS = (
    "D02-public-posterior-reachability-is-suit-invariant",
    "D03-real-early-single-lane-pass-hu",
    "D03-late-or-dead-waits-take-hu",
    "D04-posthoc-draw-does-not-enter-defense-tempo",
)
GANG_TESTS = (
    "D04-real-facade-suit-reflection",
    "D02-real-transition-not-free-ready",
    "D06-public2m-gang-no-certainty",
    COMMON_OUTCOME_CASE,
)
POOL_TESTS = (
    "D02-public-posterior-reachability-is-suit-invariant",
    "D03-joint-capacity-not-independent",
    "D04-last9m-not-certain-wall",
    COMMON_OUTCOME_CASE,
)

SPECS.update({
    "7675206658166918452": historical_spec(12, "结构资产、公开动作相容性与动态攻守",
        ["自身成组与搭子资产", "完整候选暗手", "公开动作来源与时序", "公共墙后验", "实时威胁与收益"],
        ["结构保留价值", "候选解释似然", "成牌收益", "放铳损失", "路线选择权"], INFERENCE_TESTS),
    "7674842657201425714": historical_spec(13, "七对与普通路线共享估值及胡过停止",
        ["对子结构与普通搭子", "碰后真实叫口", "公共墙可达资源", "公开过碰证据", "当前胡益与继续风险"],
        ["路线完成率", "碰牌机会成本", "即时确定收益", "未来自摸收益", "流局与截胡风险"], HU_PASS_TESTS),
    "7674471459275820323": historical_spec(14, "路线完成条件优先于名义番值",
        ["各路线完成条件", "公共资源竞争", "对手公开速度", "自身实际活张", "当前与后续收益"],
        ["完成概率", "预期番值", "成叫速度", "对手截流成本", "结果不变性"], ROUTE_TESTS),
    "7673900582792432948": historical_spec(15, "事件驱动的胡过动态阈值",
        ["当前合法胡益", "实际叫口与活张", "过胡锁成本", "座次与牌墙", "对手公开威胁分布"],
        ["即时收益", "未来胡益", "锁状态成本", "被截胡风险", "尾部损失"], HU_PASS_TESTS),
    "7673739137471499574": historical_spec(16, "公开占用下的路线速度与条件顺放",
        ["自身候选路线", "公共墙后验", "上家公开范围", "弃牌喂牌风险", "座次与当前收益"],
        ["成叫速度", "实际活张", "番型收益", "放铳与助攻风险", "路线弹性"], POOL_TESTS),
    "7672793321080753450": historical_spec(17, "优势门控的高番路线升级",
        ["自身结构优势", "剩余巡数", "公共资源竞争", "普通路线退路", "对手候选范围"],
        ["路线完成率", "预期番值", "时间成本", "竞争折损", "即时听口价值"], ROUTE_TESTS),
    "7672782178786495763": historical_spec(18, "对子上下文价值与多解释行为证据",
        ["对子与普通结构", "可碰机会", "公共占用", "公开弃牌和胡牌动作", "过手胡规则状态"],
        ["七对完成率", "普通路线速度", "候选后验覆盖", "风险", "规则合法收益"], INFERENCE_TESTS),
    "7672604695935847731": historical_spec(19, "价值加权的联合等待与多候选范围",
        ["数学等待全集", "公共墙后验", "多种对手候选结构", "各等待番值", "剩余巡数"],
        ["联合活张", "价值加权胡益", "候选不确定性", "竞争折损", "时间价值"], POOL_TESTS),
    "7672239986707565875": historical_spec(20, "杠牌作为显式状态搜索",
        ["碰杠过合法动作", "动作后手牌结构", "未知补牌分布", "公共墙后验", "威胁与工程杠分"],
        ["确定杠分", "杠后恢复率", "叫口质量", "时间成本", "对手风险"], GANG_TESTS),
    "7671869047796976931": historical_spec(21, "结构期望、碰后有效张与威胁收胡",
        ["自身结构弹性", "碰后真实手牌", "公共墙活张", "杠后风险", "对手高番威胁"],
        ["结构完成率", "碰后有效张", "即时胡益", "潜在先胡损失", "风险调整净分"], GANG_TESTS),
    "7671466198478998818": historical_spec(22, "弱势高番退出与公共范围弃牌",
        ["高番路线完成率", "无叫时间风险", "危险张", "断张与可碰通道", "对手公开范围"],
        ["退出成功率", "即时成叫价值", "截流收益", "放铳风险", "路线机会成本"], ROUTE_TESTS),
    "7671162141033925924": historical_spec(23, "延迟预算与保护叫张的停止策略",
        ["当前叫口", "公共墙活张", "延迟巡数预算", "强家威胁", "杠碰后的真实状态"],
        ["改良收益", "延迟成本", "叫张保护价值", "放铳风险", "即时兑现收益"], HU_PASS_TESTS),
    "7670781255381814564": historical_spec(24, "外部资源流通与上下文行为证据",
        ["自身现张结构", "公共资源流通", "候选对手范围", "邻张可用性", "牌墙与番值"],
        ["结构完成率", "外部供给", "候选似然", "番值收益", "时间风险"], POOL_TESTS),
    "7670389159747521792": historical_spec(25, "听口与杠状态联合搜索",
        ["当前听口", "暗杠与补杠合法状态", "补牌未知分布", "对手范围", "抢杠与杠开规则"],
        ["叫口质量", "杠分", "补牌后收益", "抢杠风险", "竞争折损"], GANG_TESTS),
    "7670037207926803721": historical_spec(26, "碰牌结构、候选等待与假设隔离",
        ["碰前后完整自身手牌", "各弃牌等待集合", "公共墙后验", "公开动作事实", "末段活动玩家与风险"],
        ["碰后结构价值", "实际活张", "风险调整净分", "候选假设一致性", "末段时间价值"],
        ("D02-D03-blind-suit-and-rank-transfer", "D01-public-synthetic-reaction", "D04-unknown-draw-does-not-prove-4m", COMMON_OUTCOME_CASE),
        status="extended_shared_algorithm",
        focus_artifact="research/xiaolaoshi_deep_learning/review_20260831/video26-corrected-nine-bamboo-runtime.json",
        focus_command="dotnet run --project research/xiaolaoshi_deep_learning/review_20260831/Video26Checks.csproj -- research/xiaolaoshi_deep_learning/review_20260831/video26-corrected-nine-bamboo-runtime.json"),
    "7660756031403773184": historical_spec(50, "路线可兑现性与一致的碰胡过成本",
        ["对子兑现机会", "普通结构利用率", "公共需求人数", "路线锁定状态", "胡过收益与风险"],
        ["路线完成率", "碰牌机会成本", "即时胡益", "未来自摸收益", "高番有效张门槛"], HU_PASS_TESTS,
        behavior="由共享路线、公共墙、反应和胡过算法承载；本片不产生大单钓或七对固定动作。"),
    "7660391044432825627": historical_spec(51, "外部威胁门控的进攻与自摸期望",
        ["外部公开威胁等级", "对手完整候选范围", "自身多路线改良", "公共墙活张", "即时胡益与自摸收益"],
        ["进攻上限", "放铳尾险", "路线数量", "自摸期望", "确定收益"], HU_PASS_TESTS,
        behavior="由共享威胁、范围、弃牌与胡过算法承载；不把视频大牌对刚或片尾结果写成阈值。"),
    "7660157720384802091": historical_spec(52, "定缺边界、无反应负证据与结果隔离",
        ["公开定缺", "自身合法手牌", "公开反应矩阵", "完整候选暗手", "决策时信息集"],
        ["候选合法性", "软证据似然", "公开资源可达性", "动作净值", "结果不变性"], INFERENCE_TESTS,
        behavior="由共享硬合法性、候选相容性和结果隔离算法承载；不把定缺扩张为暗手透视。"),
})

SPECS["7665572809577434377"] = historical_spec(
    38,
    "多威胁尾险、需求折价可达性与抢先退出",
    ["活动玩家威胁后验", "自身各动作后的向听与听口", "公共墙后验", "对手花色需求与状态跃迁", "活动付款人数和规则番值"],
    ["本家先胡收益", "多对手尾部损失", "可达改良张", "暴露时长", "路线切换成本"],
    (
        "D02-public-posterior-reachability-is-suit-invariant",
        "D03-bounded-small-loss-versus-own-continuation-ev",
        "D03-generic-public-action-compatibility-rotates-and-reverses",
        COMMON_OUTCOME_CASE,
    ),
    behavior=(
        "由共享公共墙可达性、所有活动玩家净分、动态防守时机、完整候选相容性和胡过停止算法承载；"
        "不新增7万/5万动作模板，也不把成对弃牌序列写成清一色触发器。"
    ),
)

SPECS.update({
    "7665221679534116130": historical_spec(
        39, "带退出权的路线期权与结果隔离",
        ["普通胡与高番路线状态", "异门替换数", "可枚举升级事件", "公共墙后验", "剩余巡数与活动威胁"],
        ["即时兑现收益", "高番路线完成价值", "延迟尾险", "路线选择权", "结果不变性"],
        ROUTE_TESTS,
        behavior="由共享路线枚举、公共墙可达性和胡过停止算法承载；坚持的是条件策略，不是固定条筒摸打顺序。"),
    "7664839970770668810": historical_spec(
        40, "早胡停止、升级期权与软负证据",
        ["当前合法胡益", "对子叫或搭子叫结构", "潜在杠牌状态", "公开无反应证据", "剩余巡数与失败尾险"],
        ["立即胡益", "升级收益", "关键张可达性", "听口损失", "延迟风险"],
        (
            "D02-public-posterior-reachability-is-suit-invariant",
            "D03-real-early-single-lane-pass-hu",
            "D02-no-response-soft-not-impossible",
            COMMON_OUTCOME_CASE,
        ),
        behavior="由共享胡过停止、碰杠状态转移和公开范围后验承载；不使用8筒、7筒或单钓奇偶口诀作为生产触发器。"),
    "7664375338855681290": historical_spec(
        41, "玩家信息集分离、换听候选与有限过胡",
        ["每名玩家各自可见信息", "有序公开弃牌", "候选换听结构", "替代听口可达性", "活动威胁与剩余巡数"],
        ["立即胡益", "自摸增益", "对手先胡尾险", "候选相容性", "信息集一致性"],
        (
            "D02-public-posterior-reachability-is-suit-invariant",
            "D03-real-early-single-lane-pass-hu",
            "D03-late-or-dead-waits-take-hu",
            "D04-posthoc-draw-does-not-enter-defense-tempo",
        ),
        behavior="由共享公开事件、候选暗手、玩家可见信息和胡过停止算法承载；不把晚打9条复制为固定换听模板。"),
    "7663900238586891561": historical_spec(
        42, "短墙候选后验与条件联合活张",
        ["短墙长度", "完整候选暗手", "公开计数", "有序弃牌与反应", "各候选下等待集合"],
        ["条件活张", "联合可行性", "候选后验", "先胡速度", "风险调整净分"],
        POOL_TESTS,
        behavior="由共享候选范围、联合隐藏池与短墙事件评估承载；不把打9胡8或单钓行为序列写成运行时规则。"),
    "7663720523234282787": historical_spec(
        43, "候选分支下的等待支配与杠机会成本",
        ["候选暗手分支", "各分支公开剩余张", "当前等待集合", "杠后真实弃牌", "对手速度与规则收益"],
        ["分支支配关系", "实际活张", "成牌速度", "杠分", "动作后风险"],
        POOL_TESTS,
        behavior="由共享隐藏池、等待集合和动作转移算法承载；不存在“必杀叫”布尔加分，也不固定保留5/8筒。"),
    "7663364371577310490": historical_spec(
        44, "动态花色竞争与多事件路线价值",
        ["定缺先验", "连续公开弃牌与副露", "花色竞争后验", "碰杠摸多类触发事件", "对手成牌速度"],
        ["路线完成率", "外部供给可达性", "杠分与番值", "延迟下叫成本", "高番尾险"],
        ROUTE_TESTS,
        behavior="由共享动态花色竞争、路线枚举和墙后验承载；不把连续打987条或拆3万写成固定动作模板。"),
    "7662952770646986020": historical_spec(
        45, "自缺进度、确定废张与过渡听停止",
        ["自身缺门牌数量", "预计打缺轮数", "确定废张", "结构后效与杠位", "过渡听和当前胡益"],
        ["早期成叫速度", "结构期权", "实际活张", "杠收益", "即时确定收益"],
        HU_PASS_TESTS,
        behavior="由共享向听、有效张、路线期权和胡过停止算法承载；不因本局打2筒、卡8筒或后见杠上花生成牌名规则。"),
    "7662611789493849394": historical_spec(
        46, "目标态攻守切换与真实活张逃跑",
        ["自身路线速度和上限", "所有活动对手威胁", "理论与实际活张", "剩余暴露时长", "当前可兑现小胡"],
        ["先胡退出收益", "高番路线价值", "尾部损失", "真实活张", "目标切换成本"],
        (
            "D01-defense-tempo-is-suit-rotation-invariant",
            "D03-bounded-small-loss-versus-own-continuation-ev",
            "D01-D02-public-demand-not-hidden-certainty",
            COMMON_OUTCOME_CASE,
        ),
        behavior="由共享所有活动玩家净分、动态防守时机和等待评估承载；不把打6条胡5/8条复制为逃跑规则。"),
    "7662231089745825067": historical_spec(
        47, "多番型可达图与自摸点炮收益分离",
        ["兼容番型路线图", "各路线触发事件", "公共资源竞争", "自摸与点炮规则收益", "杠后风险"],
        ["路线完成率", "自摸收益", "点炮收益", "选择权价值", "动作后尾险"],
        ROUTE_TESTS,
        behavior="由共享多路线搜索、规则计分和动作状态转移承载；清一色、大单钓或打1万不获得单视频固定权重。"),
    "7661859802238225714": historical_spec(
        48, "规则变体威胁时序与候选结构消元",
        ["换三张规则开关", "异色退出进度", "对手下叫与副露", "完整成牌候选", "安全牌和碰牌外部成本"],
        ["高番威胁后验", "有限拒胡收益", "结构可行性", "安全弃牌价值", "被先胡尾险"],
        INFERENCE_TESTS,
        behavior="由共享规则配置、完整候选范围、胡过停止和防守算法承载；不把某张碰牌或两见牌直接标为危险或安全。"),
    "7661159526623677748": historical_spec(
        49, "房规配置、需求竞争与多路线期权",
        ["显式房规", "定缺需求竞争", "自身攻守目标", "碰杠补牌状态", "兼容番型路线"],
        ["规则净分", "条件有效张", "退出收益", "杠后风险", "路线选择权"],
        (
            "D04-real-facade-suit-reflection",
            "D01-public-competition",
            "D06-public2m-gang-no-certainty",
            COMMON_OUTCOME_CASE,
        ),
        behavior="由共享房规计分、公共需求、攻守转换、杠状态与路线搜索承载；五个结果片段都只作证据，不产生动作权重。"),
    "7659695451142229254": historical_spec(
        53, "实际花色供需、攻守切换与贪番停止",
        ["定缺与实际花色需求后验", "自身快速成叫和高番路线树", "对手副露与状态跃迁", "公共墙后验", "剩余巡数与活动尾险"],
        ["先胡退出收益", "高番路线选择权", "外部喂牌成本", "真实活张", "多对手尾部损失"],
        (
            "D01-defense-tempo-is-suit-rotation-invariant",
            "D00-D01-qing-entry-and-dynamic-competition",
            "D03-generic-public-action-compatibility-rotates-and-reverses",
            COMMON_OUTCOME_CASE,
        ),
        behavior="由共享动态花色竞争、所有活动玩家净分、路线搜索、候选相容性和胡过停止算法承载；不把打5条、打1条或摸9万写成生产动作模板。"),
})


def nonempty_list(value: Any, fallback: list[str]) -> list[str]:
    if isinstance(value, list) and value and all(isinstance(x, str) and x.strip() for x in value):
        return value
    return fallback


def artifact_for(video_id: str, kind: str, case_id: str) -> str:
    spec = SPECS[video_id]
    if video_id == "7670037207926803721" and case_id != COMMON_OUTCOME_CASE:
        return spec["focus_artifact"]
    if spec.get("generalization_artifact"):
        return spec["generalization_artifact"]
    if kind == "outcome_invariance" and case_id == COMMON_OUTCOME_CASE:
        return COMMON_OUTCOME_ARTIFACT
    if kind == "suit_rotation" and video_id == "7667063064524574015":
        return (
            "research/xiaolaoshi_deep_learning/7665945910290959651/"
            "algorithm-reaudit-runtime.json"
        )
    return f"research/xiaolaoshi_deep_learning/{video_id}/algorithm-reaudit-runtime.json"


def ensure_case(repo: Path, artifact: str, case_id: str) -> None:
    payload = json.loads((repo / artifact).read_text(encoding="utf-8"))
    rows = payload.get("results", payload.get("checks", []))
    matches = [item for item in rows if item.get("id") == case_id]
    if len(matches) != 1 or matches[0].get("passed") is not True:
        raise ValueError(f"missing passed case {case_id} in {artifact}")


def upgrade_bundle(repo: Path, bundle: Path) -> None:
    raise RuntimeError("Legacy automatic application certification is retired. Use explicit expert_learning_v2 reviewed documents; no bundle was changed.")
    video_id = bundle.name
    spec = SPECS.get(video_id)
    if spec is None:
        raise ValueError(f"no reviewed specification for {video_id}")

    units_path = bundle / "knowledge-units.json"
    report_path = bundle / "ai-application-report.json"
    units_doc = json.loads(units_path.read_text(encoding="utf-8"))
    old_report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    units = units_doc.get("knowledge_units", [])
    if not units:
        raise ValueError(f"no knowledge units for {video_id}")

    for unit in units:
        candidates = nonempty_list(unit.get("candidate_actions"), ["全部合法候选动作"])
        reversals = nonempty_list(unit.get("reversal_conditions"), ["关键公开前提改变时重新计算"])
        unit["algorithm_abstraction"] = {
            "algorithmic_question": (
                f"在{spec['family']}中，如何在“{' / '.join(candidates)}”之间应用："
                f"{unit.get('decision_principle', '').rstrip('。')}？"
            ),
            "state_variables": list(spec["state"]),
            "action_space": candidates,
            "objective_terms": list(spec["objectives"]),
            "invariants": [
                "花色与座位的结构同构变换不改变算法方法",
                "具体视频ID、固定牌名和固定摸打序列不进入生产特征",
                "只使用决策时可见信息与自身手牌",
                "未来摸牌、摊牌和单局结果不回灌当前决策",
            ],
            "reversal_conditions": reversals,
        }

    units_doc["schema_version"] = 2
    units_path.write_text(json.dumps(units_doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    components = nonempty_list(
        spec.get("components") or old_report.get("implementation", {}).get("component_paths"),
        DEFAULT_COMPONENTS,
    )
    node_mapping_by_id: dict[str, dict[str, Any]] = {}
    for unit in units:
        abstraction = unit["algorithm_abstraction"]
        for node_id in unit.get("decision_node_ids", []):
            existing = node_mapping_by_id.get(node_id)
            if existing is None:
                node_mapping_by_id[node_id] = {
                    "decision_node_id": node_id,
                    "principle": unit.get("decision_principle", abstraction["algorithmic_question"]),
                    "algorithm_inputs": abstraction["state_variables"],
                    "algorithm_output": "对合法候选返回风险调整后净值、排序和可反转理由",
                    "components": components,
                }
            else:
                principle = unit.get("decision_principle", abstraction["algorithmic_question"])
                if principle not in existing["principle"]:
                    existing["principle"] += "；" + principle
                existing["algorithm_inputs"] = list(dict.fromkeys(
                    existing["algorithm_inputs"] + abstraction["state_variables"]
                ))
    node_mappings = [node_mapping_by_id[key] for key in sorted(node_mapping_by_id)]

    tests = []
    generalization = []
    command = spec.get("focus_command") or (
        "dotnet run --project research/xiaolaoshi_deep_learning/local_video_checks/"
        f"LocalVideoChecks.csproj --no-build -- research/xiaolaoshi_deep_learning/local_video_checks/"
        f"video{spec['order']}-input.json research/xiaolaoshi_deep_learning/{video_id}/"
        "algorithm-reaudit-runtime.json"
    )
    local_artifact = spec.get("focus_artifact") or f"research/xiaolaoshi_deep_learning/{video_id}/algorithm-reaudit-runtime.json"
    local_payload = json.loads((repo / local_artifact).read_text(encoding="utf-8"))
    if local_payload.get("ok") is not True:
        raise ValueError(f"local algorithm audit is not green for {video_id}")
    local_rows = local_payload.get("results", local_payload.get("checks", []))
    tests.extend(
        [{
            "kind": "focused",
            "passed": True,
            "command": command,
            "artifact": local_artifact,
            "result": f"{len(local_rows)}/{len(local_rows)}",
        }, {
            "kind": "csharp_runtime",
            "passed": True,
            "command": (
                "dotnet build research/xiaolaoshi_deep_learning/local_video_checks/"
                "LocalVideoChecks.csproj --no-restore && " + command
            ),
            "artifact": local_artifact,
            "result": "build and explicit runtime audit passed",
        }]
    )
    for kind, case_id in spec["tests"].items():
        artifact = artifact_for(video_id, kind, case_id)
        ensure_case(repo, artifact, case_id)
        generalization.append(
            {
                "kind": kind,
                "passed": True,
                "artifact": artifact,
                "test_case_id": case_id,
                "command": command if artifact == local_artifact else "共享正式算法的显式重审产物，见 artifact",
            }
        )

    old_behavior = spec.get("behavior") or old_report.get("implementation", {}).get("behavior", "")
    evidence_index = json.loads((bundle / "evidence-index.json").read_text(encoding="utf-8"))
    source_sha256 = old_report.get("source_sha256") or evidence_index.get("source_sha256")
    old_visibility = old_report.get("visibility_contract")
    visibility_contract = old_visibility if isinstance(old_visibility, dict) else {
        "uses_hidden_information": False,
        "public_inputs": ["本家手牌与合法动作", "公开定缺、牌河、副露和反应", "活动玩家、公共墙后验与规则状态"],
        "prohibited_inputs": ["对手真实暗手", "未来墙序或摸牌", "终局摊牌与单局结果"],
    }
    report = {
        "schema_version": 2,
        "video_id": video_id,
        "source_sha256": source_sha256,
        "knowledge_unit_ids": [unit["id"] for unit in units],
        "decision_node_ids": sorted({node for unit in units for node in unit.get("decision_node_ids", [])}),
        "visibility_contract": visibility_contract,
        "abstraction_contract": {
            "algorithmic_question": f"如何把本片的{spec['family']}原则实现为可跨牌例复用的状态决策？",
            "state_variables": spec["state"],
            "action_space": sorted({action for unit in units for action in unit["candidate_actions"]}),
            "objective_terms": spec["objectives"],
            "invariants": [
                "花色与座位结构同构时方法不变",
                "固定视频牌谱不进入生产触发器",
                "硬合法性先于软后验",
                "结果字段不参与事前决策",
            ],
            "reversal_conditions": sorted(
                {item for unit in units for item in unit.get("reversal_conditions", [])}
            ),
            "runtime_video_specific_literals": False,
        },
        "node_mappings": node_mappings,
        "implementation": {
            "status": spec["status"],
            "behavior": old_behavior,
            "component_paths": components,
        },
        "anti_overfit_review": {
            "hard_coded_video_id": False,
            "fixed_tile_sequence_trigger": False,
            "tile_name_specific_multiplier": False,
            "outcome_leakage": False,
            "single_video_numeric_weight": False,
            "audited_component_paths": components,
        },
        "generalization_evidence": generalization,
        "calibration": {
            "video_derived_numeric_weights": False,
            "mode": "qualitative_or_existing_calibration",
            "note": "本视频只验证共享算法结构和边界，不产生单视频数值权重。",
        },
        "test_evidence": tests,
        "verification_scope": "正式C#入口、显式公开状态、跨花色与破坏前提反例；不使用视频结局作为输入。",
        "conflict_review": {
            "status": "resolved",
            "known_boundaries": [
                "视频动作不是监督标签；与精确牌效或工程规则冲突时以正式状态算法为准。",
                "没有完整公开状态时只保留方向性原则，不宣称该局动作全局最优。",
                "单视频不校准任何概率、阈值或乘数。",
            ],
        },
        "completion_status": "algorithmically_implemented_and_verified",
    }
    if not report["source_sha256"]:
        raise ValueError(f"missing source hash for {video_id}")
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    card_path = bundle / "knowledge-card.md"
    if card_path.exists():
        marker = "## 2026-09-02 算法抽象重审"
        card = card_path.read_text(encoding="utf-8")
        if marker not in card:
            addendum = (
                f"\n{marker}\n\n"
                f"本片现在只作为“{spec['family']}”的事实与原则证据。生产 AI 读取的是算法合同中的状态变量，"
                "在全部合法动作间比较目标项，并按反转条件重新计算；视频里的具体牌名、摸打顺序和老师最终动作不作为运行时触发器或监督标签。"
                "本次已通过花色轮换、结构变体、破坏前提和结果不变性四类跨牌例门禁；严格结果见 `validation-report.json`，"
                "运行证据见 `ai-application-report.json` 所列 artifact。\n"
            )
            card_path.write_text(card.rstrip() + "\n" + addendum, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("repo", type=Path)
    parser.add_argument("bundles", nargs="+", type=Path)
    args = parser.parse_args()
    repo = args.repo.resolve()
    for raw in args.bundles:
        bundle = raw if raw.is_absolute() else repo / raw
        upgrade_bundle(repo, bundle.resolve())
        print(bundle.name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
