# 孤张生产审查

当前生产实现为 `SichuanIsolatedTileEvaluator`，`SichuanHandShapeEngine` 和 `SichuanDecisionEngine` 使用其边际进张/孤张优先级；精确上听与整手有效进张仍是更高优先级。原实现遗漏孤张自身摸同牌成对的有效机会，本轮已补入。

本轮没有把中张、偏张、幺九写成固定分值；位置只作为同速、同整手条件下的局部参考。
