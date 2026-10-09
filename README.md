# 嘉豪训练器 · 精简可编辑工程（v2）
解压到 D:/Codex 的新目录，将整个目录交给 Claude Code，修改 game/。Play.cmd 运行、Edit.cmd 编辑、Verify.cmd 检查九个活动入口、Export.cmd 导出独立 Windows 游戏。

主工程ZIP用于运行与代码、UI、场景编辑。要编辑三维模型，再将配套的「嘉豪训练器-当前模型源.zip」解压到同一上级目录，合并同名工程文件夹；它补充 game/source_art 与 game/blender-dependencies。模型源依赖主工程中的运行贴图，两个包一起解压就是完整的当前可编辑工程。可直接用本地已整理好的完整目录，无需重复解压。

主包保留当前主流程与九个活动入口实际引用的源代码、场景、运行资源；配套包保留71个必要Blender编辑源，每个运行GLB的来源映射见 delivery/model-source-map.json。当前场景引用的旧命名资源仍可能是父场景依赖，按真实引用保留，不按日期删除。旧候选、重复总装、过程截图、离心室、缓存与自动备份没有打包。原始完整素材仍在独立活动工程，不依赖旧交付归档。

Blender源文件的重复嵌入贴图改为包内共享文件，几何、骨骼、动作和材质不修改。三维编辑需另行安装Blender；包带Godot 4.7.2、导出模板、Python标准库和Node。私人配置、密钥、聊天、玩家存档和模型权重不包含。

可选资料在 docs/optional：只给关卡就指定01；只给画风就指定02；全部给就读该目录README；不给就将整个optional目录移到工程外。根CLAUDE.md明确不默认读取这些资料。

校验见 delivery/verification.json、blender-dependency-audit.json；主包逐文件清单为delivery/file-manifest.json，模型源清单为delivery/model-file-manifest.json；最终ZIP的SHA256在压缩包旁文本，CRC记录在交付工作区delivery/zip-verification.json。功能通过不代表用户已经认可画面、手感或训练效果。
