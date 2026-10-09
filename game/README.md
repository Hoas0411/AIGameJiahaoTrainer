# 嘉豪训练器可编辑工程
当前代码快照：2026-10-08；架门缝逻辑包含 R19 三档速度。配置版本字符串 0.9.0-training-preview 是历史名称，不代表此代码只到早期版本。
从上级目录使用 Play.cmd、Edit.cmd、Verify.cmd、Export.cmd；Godot 4.7.2、Python 标准库和 Node 运行时已随包附带。
scenes/ 保存布局；scripts/ 保存逻辑；resources/ 保存配置；assets/ 保存运行模型、材质、字体、音频；source_art/ 保存 Blender 和设计源。source_art 由配套模型源包提供，仅保留当前资源对应的必要编辑源；映射见上级delivery/model-source-map.json。
选关唯一登记：scripts/course_registry.gd；玩家说明投影：resources/training/course_catalog.json。基础训练无需模型服务；AI 和语音需自行配置服务及模型。包内没有私人配置、存档和权重。
