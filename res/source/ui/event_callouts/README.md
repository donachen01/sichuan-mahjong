# 四川牌桌事件字资产记录

本目录保留六类牌局事件字的可编辑 Blender 源工程。成品由本项目内的确定性脚本逐层搭建和导出，未调用图像生成服务，也未复制参考游戏像素。

| 名称 | 设计构成 | 游戏显示尺寸 | 透明成品 |
| --- | --- | ---: | --- |
| 碰 | 翡翠圆印、旧铜外环、青绿光点 | `360×180 px` | `res/art/ui/event_callouts/peng.png` |
| 杠 | 深青玉匾、旧铜边、金色嵌线 | `360×180 px` | `res/art/ui/event_callouts/gang.png` |
| 胡 | 朱砂圆印、克制金粒 | `360×180 px` | `res/art/ui/event_callouts/hu.png` |
| 自摸 | 暖象牙签、翡翠双环 | `360×180 px` | `res/art/ui/event_callouts/self_draw.png` |
| 杠上花 | 朱砂长印、三枚淡金花瓣 | `420×180 px` | `res/art/ui/event_callouts/gang_self_draw.png` |
| 抢杠胡 | 深朱砂核心、锐利金线、无震屏 | `420×180 px` | `res/art/ui/event_callouts/qiang_gang_hu.png` |

重建命令：

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/3d/generate_sichuan_event_callouts.py
```

源工程：`res/source/ui/event_callouts/sichuan_event_callouts.blend`。其中文字、底印、环、嵌线、金粒与花瓣均为独立对象，可继续人工调整。
