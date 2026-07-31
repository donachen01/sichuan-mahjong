# 四川麻将 2.6.14 Android Release 报告

日期：2026-07-31

## 成品

- APK：`build/android/SichuanMahjong-2.6.14-release.apk`
- 大小：`150,166,278` bytes
- SHA-256：`0009a9caef16b20c40e06066c6378c051e035bd72dc577e5819cfcca27e5cc0f`
- 包名：`com.chendong.sichuanmahjong`
- 版本：`versionCode=274`、`versionName=2.6.14`
- minSdk / targetSdk：`24 / 35`
- ABI：仅 `arm64-v8a`

## 完整性、签名与入包证明

- Godot/.NET 导出：`export_result=0`、`message_count=0`。
- `zipalign -c -p 4`：通过。
- APK Signature Scheme v2/v3：通过；签名证书 SHA-256 为 `9ca9ba45de9a950e19f140e2d706d0fe187e90070601d162becf8848b6a75600`。
- ZIP 完整性：通过；禁止的 `assets/tests`、`assets/evidence`、`assets/docs`、`assets/tools` 与 `.pdb` 条目为 `0`。
- APK 内 `mahjong_tile_body.glb` 导入场景与本地当前导入场景逐字节一致，SHA-256 均为 `bcc2ed3a8cad779a5c5db38947c094aa64dd108377a041ac294e1deac1e02222`。
- APK 包含本轮 `SichuanTableStage3D.gdc` 和 `SichuanTile3D.gdc`；2.6.14 的副露模型门禁与统一加厚牌体均进入最终签名包。

## 验证边界

发布前固定清单为 `27/27 PASS`，真实 Metal 碰杠画面见 `evidence/ui_meld_model_consistency_20260731/`。当前 `adb devices -l` 为空，因此 Android 最强证据到正式签名、完整性和可安装 APK；没有 Android 真机安装、版本读回、启动、触控或完整牌局证据。
