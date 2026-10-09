# 嘉豪训练器：Claude Code 开发入口
这是当前活动工程的独立交接快照，不是只有 EXE/PCK 的试玩包。工程在 game/，打开 project.godot。用户的新指令优先。

## 基本约束
- 编辑 game/，不要编辑 .godot 缓存或在导出目录继续开发。原始源文件保留；先查看具体模块，再做有范围的改动。
- docs/optional/ 是可选上下文。未经用户明确选择，不要自动阅读、加载或引用其中的关卡说明、审美偏好、原始文档及历史规则。用户可移动或删除该目录，基础训练、编辑和打包仍应可用。若偏好未提供，按当前游戏外观保守修改；需要新设计取向时向用户询问。
- 编写或维护正式文档前读 docs/governance/00-document-governance-methodology.md 和 docs/README.md，保持单一真相源。
- 新三维模型必须先完成设计图，再用 Blender 制作，保留可编辑 .blend，保存实际打开最终文件的 Blender 界面截图。进行建模/关卡/材质/灯光/画面升级前读取 docs/boundaries/画面质量规范.md。不得用 Godot 原语或脚本造网格冒充 Blender 源模型。
- 修 Bug 前在 docs/错误与Bug修复日志/ 建任务目录，记录规划、诊断、实现和验证。
- 项目默认 D:/Codex 存储，只保留同一作品最新两份完成交付，超额移到 D:/Codex/旧版本与过期内容，不直接删除。原始素材、唯一源工程、当前依赖及长期记忆独立保留；不能依赖归档。交付成功后使用交接包 tools/Archive-Versions.ps1 登记。用户指定回退优先于版本号和修改日期。
- 不能安装、调用或依据 token-efficient-workflow 执行；不能自行增加子代理或审批停顿。
- 普通关卡共用玩家、输入、武器、运动、历史数据；跨模块改动说明消费者并做对应回归。离心室是独立项目，不属于此包。测试通过不等于用户已经认可画面或手感。

## 操作入口
- Play.cmd：运行当前源工程；Edit.cmd：编辑；Verify.cmd：导入与基础冒烟；Export.cmd：生成新的可独立运行 Windows 包。
- game/tools/workbench.ps1 保留 context / begin / check / finish 流程，使用包内 workbench 和 Python。context 的默认读取清单只含本文件、game/README 和底座必需规则，不自动读取 optional。
- 精简包已移除历史作者和旧打包脚本。当前便携入口见 tools/portable.ps1；三维源文件来自配套模型源包，若尚未解压该包，修改三维前先由用户提供。不要因此生成原语模型冒充Blender源。

本交接包 check --engine 的隔离检查使用 handoff_smoke.gd，仅证明九个活动关卡初始化，未覆盖完整枪械、移动、成绩、AI或视觉回归；原 --smoke 历史入口不作为当前默认门。
