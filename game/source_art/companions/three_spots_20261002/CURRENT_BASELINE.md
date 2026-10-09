# 当前采用的外观基线

用户于 2026-10-02 指定恢复到 candidate_r20.png 所展示的一步，并先接入游戏试玩。

- 当前可编辑源文件：mouse_repaired.blend
- 当前重建入口：restore_approved_r20.py（不要运行 repair_final.py 的后续失败路线）
- 当前导出入口：export_final.py
- 游戏资源：assets/models/companions/three_spots_20261002/mouse_repaired.glb
- 试玩入口：项目根目录 launch_game.cmd，不是旧打包入口 play_training.cmd。
- 游戏截图：evidence/mouse-three-spots-20261002/restored_r20/。

这次是按用户指定基线恢复后的试玩，不宣称三处外观问题全部通过用户验收。Blender 与游戏光照存在差异，右侧发际仍有可见尖边；没有继续修改用户指定的外观。抱起/放下等局部运行检查通过，全游戏未回归。

后续失败的 .blend / .glb 已移入 D:/Codex/旧版本与过期内容/嘉豪训练器/麦小鼠三处修复-后续失败候选-20261002；当前源文件与游戏资源不依赖归档。
