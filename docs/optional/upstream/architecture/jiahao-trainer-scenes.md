# 嘉豪训练器：场景与资源契约

> 状态：canonical · 层：architecture · 真相域：jiahao_scene_contract
> 上位：[文档治理](../governance/00-document-governance-methodology.md)
> 验证事实见 [验收记录](../inspection/jiahao-trainer-2026-09-09-0.6.md)。

本游戏是用户明确要求的独立 Godot 3D 客户端，位于 apps/jiahao-trainer。原仓库 2D 小镇、网页前后端规划不作为本游戏实现约束，也不被改写。

当前可运行与交付关卡集合由 `scripts/course_registry.gd` 唯一拥有；主会话、选关与陪伴命令消费该目录，历史ID不重新编号。下表中的退役场景条目仅说明原始源文件的所有权，不代表仍可进入游戏或进入发布包。当前八场景清理证据见[精简验收](../inspection/jiahao-catalog-reduction-2026-10-01.md)。

## 模块与唯一编辑入口

以下路径相对于 Godot 项目。

| 真相域 | 所有者 |
| --- | --- |
| 离心室历史白模、测绘资料和 Blender 源文件 | 已转移到独立项目 `D:/Codex/项目/离心室独立项目_20261001`；嘉豪训练器不再加载这些资源 |
| 新障碍物、建筑与小型静态模型的制作入口 | D:/Codex/ai-game-workbench/production/profiles/level_modeling.json 与 production/methods/level_modeling.md；每个任务通过嘉豪 workbench 适配器登记具体资源范围 |
| 离心室主体版与完整版游戏包装 | 独立项目的 `source/scenes/levels/centrifuge_rebuilt` 与 `game/Build28`，不属于嘉豪训练器发行包 |
| 会话、换关、计分、结算 | scenes/main.tscn + scripts/main.gd |
| 五个专项科目的布局、碰撞、出生点、敌人摆放 | scenes/levels/01_peek_squad.tscn、02_centrifuge.tscn、03_corner_entry.tscn、04_tracking.tscn、05_jet_breach.tscn |
| 航天 2.0 整图与区域实例 | scenes/levels/06_space_city2.tscn、space_city2/*.tscn；scripts/space_city.gd 只管理水面 |
| 整图俯视导览与跳转 | scenes/ui/space_map.tscn + scripts/space_map.gd；目的地为 Destinations/Marker3D |
| 三套输入预设及出处 | scenes/ui/input_profiles.tscn + scripts/input_profiles.gd；resources/input_profiles.json |
| 敌人可见弹道余迹 | scenes/effects/tracer.tscn + scripts/tracer.gd；不参与伤害 |
| 敌人配置、重生、清除目标数量 | 各关卡根节点 + scripts/level.gd |
| NPC 行为、感知、受击、失能 | scenes/actors/enemy.tscn + scripts/enemy.gd |
| 大头角色包装、持枪及骨骼接口 | scenes/actors/doll.tscn + scripts/doll.gd |
| 玩家运动、视角与 QE 侧头 | scenes/actors/player.tscn + scripts/player.gd；侧头参数由 scripts/motion_profile.gd + resources/motion_baseline.tres 拥有 |
| 枪模、开火、换弹、镭射 | scenes/weapons/weapon.tscn + scripts/weapon.gd |
| 第一人称手臂 | scenes/weapons/first_person_arms.tscn |
| 喷气、C4 携带、施放与冷却 | scenes/abilities/vyron_kit.tscn + scripts/abilities.gd |
| 技能弹体、吸附、爆炸遮挡 | scenes/abilities/magnetic_charge.tscn、thumper_shell.tscn + scripts/gadget_projectile.gd |
| 爆炸 / 控制冲击波 | scenes/abilities/blast.tscn + scripts/blast.gd |
| 枪械数据 schema | scripts/weapon_profile.gd（原生 Resource，不是行为节点） |
| AWM / 训练步枪参数 | resources/weapons/awm.tres、rifle.tres |
| 弹道、弹着 | scenes/effects/bullet.tscn、impact.tscn 及各自脚本 |
| 菜单、HUD、设置、结果 | scenes/ui/interface.tscn + scripts/interface.gd |
| 按键重绑定 | scenes/ui/keybindings.tscn + scripts/keybindings.gd；user://keybindings.cfg |
| 第三方腰射转换 | scenes/ui/input_calibration.tscn + scripts/input_calibration.gd；只成功响应才写设置 |
| 个人设置 / 最近 100 次结果 | user://settings.cfg、user://training_history.json |
| 集成验证 | scenes/testing/test_runner.tscn + scripts/test_runner.gd |
| 本体等效状态 | [参数校准记录](../design/jiahao-trainer-calibration.md) |
| 陪伴会话、偏好与记忆持久化 | scenes/companion.tscn + scripts/companion.gd；user://companion.json |
| 麦小鼠实体与跟随 | scenes/actors/companion.tscn + scripts/companion_actor.gd |
| 陪伴聊天、偏好编辑、记忆确认 | scenes/ui/companion.tscn + scripts/companion_ui.gd |
| 模型适配与受限智能体工具 | companion-service/server.mjs；本机 127.0.0.1:18765 |
| 陪伴人格、情绪与可纠正培养状态 | scripts/companion_mind.gd；由 Companion 持有，写入原 user://companion.json 的 mind 字段 |
| 三套训练路线定义与运行状态 | scripts/companion_routes.gd；main.tscn 的 CompanionRoutes，读取现有训练历史 |
| 培养与路线选择界面 | scripts/companion_studio.gd；由既有 CompanionUI 惰性创建，使用当前界面皮肤 |
| 共享运动 / 威龙参数 | scripts/motion_profile.gd + resources/motion_baseline.tres；scenes/ui/motion_settings.tscn + scripts/motion_settings.gd；user://motion.cfg |
| 第七至十二专项及指标 | scenes/levels/07_range.tscn 至 12_motion.tscn + scripts/special_drill.gd |
| 可行走训练大厅 | scenes/levels/13_hub.tscn + scripts/training_hub.gd |
| 快速选关、难度、无敌开关 | scenes/ui/hub.tscn + scripts/hub_ui.gd |
| 非暂停气泡与待发消息队列 | scenes/ui/bubble.tscn + scripts/bubble_ui.gd；WorldBubble / EdgePrompt 承载正文，实体 Speech / Label3D 只作投影锚点 |
| 麦克风采集、分句、WAV 编码 | scenes/voice_input.tscn + scripts/voice_input.gd；user://voice.cfg |
| 本地语音识别 | companion-service/speech.mjs；POST /transcribe |
| 投掷轨迹预览 | scenes/abilities/trajectory.tscn + scripts/trajectory.gd |

所有运行行为脚本都有场景承载。角色由 Blender Armature 蒙皮导出，GLB 内含 Skeleton3D、蒙皮网格、AnimationPlayer。Doll 提供 play_pose 和 bone_world 接口，命中区域读取实际骨骼随姿态移动。骨骼名称是接口；更换骨架需要同步映射。

## 编辑与运行边界

### 活动专项共用玩家

当前活动专项均实例化 `scenes/actors/player.tscn`，共用 `scripts/player.gd`、`scenes/weapons/weapon.tscn`、`scripts/weapon.gd` 和技能场景。运动及眼高由 `resources/motion_baseline.tres` / `MotionProfile` 与既有 `user://motion.cfg` 设置链拥有；灵敏度、FOV、枪械与输入配置经主流程 `main.gd.apply_settings()` 和既有 UI 设置入口应用。关卡不复制玩家脚本、参数资源或用户配置，不通过实例覆盖改变这些共享参数。共享源修改后，各关卡下一次加载读取同一来源。

录像校核相机允许单独记录来源时间、位置、朝向和镜头参数；其用途是建筑投影比对，必须与可玩玩家的真实走查证据分别标明。离心室的后续校核在独立项目内进行，不写回嘉豪训练器的共享玩家参数。


### 0.8 大厅、气泡和语音契约

无启动参数时进入可走动大厅；F 选择附近训练舱，Tab 打开当前活动训练目录并选择难度 / 无敌。活动关卡由 `course_registry.gd` 登记；离心斜坡编号 1 保留为空位，不允许加载。metrics 写入既有 training_history.json 的 drill_metrics，受限工具可读取，不能复制一套成绩。暂停页可提前结算；直接返回大厅放弃未结算本轮。测试用 training_history_test.json 隔离。

F7 页面继续作为暂停的偏好 / 长聊天编辑器。Enter 使用独立气泡，世界继续运行；player.controls_blocked 阻止打字触发移动、技能和开火，关闭后恢复鼠标。最多排队四条显式消息，逐条交给 Companion；切关清空未发内容并取消语音请求，Companion 的 epoch 继续取消旧模型结果。瞄准时实体移向侧面；安静风格普通事件只反馈动作，重要衔接 / 结算仍可出文字。

气泡正文保留完整回复及段落，按换行后的高度纵向扩展，不显示方位解释或“F7 查看全文”小字。角色可见网格包围盒未完整入镜、被遮挡或头顶气泡空间不足时，EdgePrompt 使用右侧固定卡片：上沿为屏高24%、右边距30个逻辑像素，宽270像素，向下增高并避让弹药栏；完整入镜且空间足够时使用 WorldBubble。超过可用屏高的极长文字在原框内滚动并暂停自动消失倒计时；这些布局状态不写入聊天正文。

两种回复框由同一 scripts/dialogue_frame.gd 绘制米白框体及连续圆钝边角；scenes/ui/bubble.tscn 持久保存正文、名字、强调线和抱框 Mascot 节点。resources/ui/dialogue_mascot 的七张 AtlasTexture 对应 CompanionActor.FaceExpression 的平静、哭泣、开心、兴奋、得意、生气、害怕。BubbleUI 仅投影 CompanionActor.expression，隐藏期间仍同步；受击、拥抱、训练反馈、持续时长及恢复平静继续由模型原有逻辑拥有，UI 不另建情绪判定或计时器。

语音模式为关闭、E 切换、E 按住；保存模式也不会在启动时自动录音。失焦、暂停、切关停止采集。AudioStreamMicrophone 进入静音捕获总线，不回放麦克风；能量门限、短前置缓冲、0.7 秒停顿和最长 10 秒切段负责分句，最多排队三段。界面显示状态、电平、转写；转写进入同一气泡队列。

POST /transcribe 继承回环 Host / Origin 限制，校验固定 16kHz mono PCM16 WAV 的头部、长度和 0.25–12 秒范围；静音不调用识别器。服务只运行本机配置指定的 whisper-cli 和模型，临时录音路径由程序生成，不接受用户文件路径 / 命令。完成或失败均删除临时音频；转写按普通聊天保存。识别和聊天各自限制并发。speechReady 只检查文件存在，真实识别才证明可用；本地识别不代表聊天模型也一定离线。

### 陪伴系统契约

训练判定与历史成绩仍由 main.gd 拥有。Companion 只消费击倒、击倒后五秒内喷气与结算事件；衔接事件不代表已经验证入掩体、跳拉或完整嘉豪动作。每次击倒提供人物动作反馈，普通自动台词至少间隔七秒；聊天请求优先于自动台词。新会话和修改偏好会取消旧请求，旧结果不得进入新会话。

CompanionActor 使用独立可编辑的原创鼠耳几何角色，没有官方麦小雯模型；它只碰环境，不挡玩家、不吸收子弹。跟随使用世界坐标下的玩家落地轨迹点，不以镜头朝向或瞄准状态重算站位。离开 3.8 米并持续 0.4 秒后起步，靠近至 2.2 米内停止追赶；加减速、身体转向、步幅动画与自然转头由本地物理脚本执行。胶囊宽度探测及地面探测用于局部避障、防止直接跨入悬空区域；严重掉队仅在镜头外寻找近期地面轨迹恢复，复杂跨层仍非完整导航网格寻路。角色选择拥有对话身份与默认称呼，不替换威龙的现有手臂或大厅模型。模型仅可建议 idle / nod / cheer，具体表现由实体脚本执行。

启用陪伴时，大厅在展台旁显示实体；训练出生与召回优先选择玩家左前方的无遮挡位置，之后独立停留或循迹跟随，允许离开视野，不占据固定镜头槽位。召回按钮同时开启实体并关闭聊天面板，不能仅令一个镜头背后的节点 visible=true 就认定可见性验收通过；验收需检查正常出生点在摄像机视锥内并查看真实渲染。

companion.json 保存角色身份、独立自定义称呼、交流风格、伴侣设定、最多三十条明确记忆与最近四十条聊天；以临时文件替换写入。训练数据只有 training_history.json 一份来源，陪伴不复制或修改分数。记忆编辑器支持纠正和删除；智能体 propose_memory 仅产生提议，玩家确认后才写入，不能把推测直接固化。

客户端通过 POST /companion 向本机服务发送 kind、message/event、profile、memories、history、conversation。响应包含 text、action、source=ai、memory 与 tools。服务仅监听回环地址并拒绝浏览器 Origin；无外部网页跨域权限。模型地址与密钥只在本机 companion-service/config.local.json 或 JH_AI_KEY 中配置，不写入 PCK。该本机服务不是可公开部署的多用户网关。

服务适配 Ollama /api/chat 和兼容 chat/completions 的模型。工具限定为 read_training、read_memories、propose_memory；最多四轮，每轮最多四个工具调用，共用超时预算。不存在任意执行、改分、写文件工具。运行日志不输出密钥与玩家聊天。云端模式的输入会发送给所配置的服务商，界面明确提示并默认关闭 AI。

AI 开关立即保存；开关开启不代表模型已经连接。GET /health 分别返回 configured 与 ready，以及非敏感的模型名/原因。本地模式检查 Ollama 模型列表，云端模式的 ready 仅表示已配置，真实回复才验证凭据。客户端可以启动同目录的固定启动脚本；启动脚本按本机配置启动 Ollama，绑定回环地址、禁用云端功能，并使用配置的模型目录。配置字段 ollamaExecutable / ollamaModels 只供本机启动使用。

失败原因区分缺少配置、模型未下载、运行程序未启动、凭据错误、超时与输出错误。历史备用回复不送入模型上下文，以免真实模型模仿“请开启AI”的系统提示。软件/模型下载与校验属于部署，不在玩家每次发消息时进行；本机运行文件位于 tools/ollama，私人配置与模型权重不纳入代码版本控制。

模型返回自然语言而非约定 JSON 时，可将真实模型文本作为台词呈现，但动作固定为 idle；残缺 JSON 和空回复仍视为错误，不得执行未验证动作。玩家使用“记住：”明确输入的记忆提议优先保留，模型没有再次提议不能抹掉它；保存仍需玩家确认。

无模型、请求失败、响应格式错误时使用标明来源的备用台词；训练不会等待网络。备用台词不是模型生成的自由聊天。UI 打开时暂停训练并释放鼠标，关闭时恢复原先状态；服务请求和 UI 在暂停期间继续响应。基础游戏无需 Node；启用模型服务需要 Node 22+，独立陪伴包可携带 Node 运行时。

source_art/*.blend 是模型编辑源，assets/models/*.glb 是导出物；Godot 包装场景拥有摆放、碰撞、音效和行为。不要编辑 .godot 导入缓存。source_art/.gdignore 阻止 Godot 自动调用 Blender 导入源文件。

关卡建模是**制作时的专业 Agent**，不属于运行时 `packages/agent-core` NPC 决策，也不直接获得修改共享玩家、武器或暂停中的离心室权限。它先交付四视图和接口特写供用户审批；审批前不得调用付费 Hyper3D。高质量候选进入 Blender 保存可编辑源文件，再由 GLB 导入 Godot。大箱、小箱等可拼关卡的单元各为独立源对象/资产，双箱只用独立实例组合。几何与材质分别校核：近距离检查直边、平面、接口、空洞/内壁和异常凸起；在游戏相机下检查材质精度与移动视角时的重叠面闪烁。详细方法和人工验收门只由上述 workbench 方法文件拥有，场景文档不复制其操作清单。

场景持久保存所有房间几何、碰撞、灯光、相机和控件。运行脚本只做移动、状态、UI 更新及必要的场景实例化，不在启动时生成世界。

专项训练场景可提供 `CompanionStand: Marker3D` 作为本关陪伴出生点；主会话仍调用共享陪伴重置，再应用该位置。没有标记时保持原默认行为。该标记只决定关卡空间安排，不复制陪伴移动控制器。Gridshot 使用关卡点击工具，临时关闭共享玩家的普通战斗输入，仍由同一个 player.gd 处理鼠标、相机与移动。退出关卡时由 start_session 恢复普通战斗状态与默认90秒时长；专项关卡仅覆盖自己的时长。原步枪、AWM和 MotionProfile 不按关卡分叉。

专项关卡的 `training_focus` 元数据折叠自动陪伴回复，并在折叠时隐藏空闲气泡；玩家主动聊天及其回复仍会展开。`training_modal` 组内的成绩界面通过 `is_open()` 表达遮挡状态，BubbleUI 在其打开时隐藏自动气泡，保留主动聊天与 F7 入口。专项参数保存在主会话 `training_options`，用于本次启动内重开；它不写入共享玩家设置。逐关玩家说明由 `resources/training/course_catalog.json` 投影到 F6 目录；专项成绩界面读取现有会话与关卡 metrics，历史继续由原 main.gd 持有，禁止另建成绩存储。

F8 继续拥有共享运动校准，F9 用于关卡自己的选项；F6/F9 与原保留键一起禁止绑定为战斗动作。专项 `live_stats()` 可提供适合本关的实时统计，避免持续靶显示无意义的击倒数；可选 `session_time()` 由主会话读取，使预备倒计时不消耗正式训练时长。没有这些方法的原关卡仍使用主会话默认逻辑。

`training_session_context.gd` 是只读证据采集器，记录原玩家输入、运动资源、两把共享枪械、胶囊半径、物理频率、视口参数与训练器版本的内容指纹，并记录本轮站位、跳跃、蹲伏及参数修改。它不持有第二份可编辑玩家配置、不写个人参数。关卡在自己的 metrics 中返回该记录，主会话写入现有历史。比较不同站位、不同目标尺寸或参数中途变化的成绩时，界面必须保留区别。

`training_comparison.gd` 只读取既有历史，向成绩页投影前五轮兼容记录的中位数；不另建历史或排行榜。关卡、难度、种子、靶参数、武器/瞄具组合、版本与玩家参数必须相容；中途调整门缝、玩家参数变化和定点练习中的明显走动、跳跃、蹲伏不参与对照。未完成时长、零次射击、旧版缺少必要证据的记录不伪装成可比数据。首发延迟无样本时显示缺失，不显示零毫秒。

tools/build_assets.py、blender_assets.py、upgrade_scenes.py、polish_assets.py 是离线作者工具，正常编辑和运行不调用它们。人工修改后不要重跑覆盖同名资源；生成器不是人工编辑后的上游真相源。模型从 .blend 导出覆盖对应 GLB，关卡直接编辑 .tscn。

NPC 实例可覆盖导出参数；大厅难度在加载时覆盖反应时间与命中概率，专项动作覆盖箱后动作列表。关卡 target_count 为 0 时重生，free_roam=false 时还会定时结束；大于 0 时以清除数量完成。第六关 free_roam=true。

碰撞层：1 环境；2 NPC 命中区域；3（位值 4）玩家。NPC 物理体只碰环境；玩家子弹扫描环境和 NPC；NPC 子弹扫描环境和玩家；感知扫描环境和玩家；技能爆炸用环境射线阻挡范围效果。头、胸、腿是独立命中区域。

资产包括 Blender 角色、两把枪、手臂、两种投掷物、箱子和墙板，辅以原生几何坡道、地面、标线、反应器及灯架。网格、镜瞄、喷气速度线 shader 独立保存；WAV 为原创合成音频。Noto Sans SC 字体许可在 assets/fonts/OFL.txt。基础训练不依赖 Blender、Python 或网络；可选在线腰射校准依赖第三方 HTTP 服务，失败保留原设置。

默认 Forward+，使用 SSAO、阴影与低强度辉光。导出包 Compatibility.cmd 可切换 OpenGL；渲染表现随渲染器变化。


## 动画与外部实测边界

武器和技能 AnimationLibrary 位于 resources/animations。第一人称手部脚本由 first_person_arms.tscn 承载，脸部外部材质由 Doll 覆盖模型材质。measure_delta_input.ps1 是测量另一款游戏的独立 Windows 工具，不是 Godot 游戏运行依赖；只写 user://delta_measurements JSON，由训练器设置页明确导入。


## 0.5 编辑接口

weapon_actions.tres 的 bolt_pull、bolt_lift、magazine_drop 是浮点属性轨道；在 Godot 动画面板编辑，不能用整数首帧导致浮点插值被截断。拉栓中自动退出贴镜视角，结束后恢复仍按住的瞄准。换弹时保留弹匣在可见范围。

NPC 新增 low_ready、aim、crouch_aim 动画；HeldWeapon 跟随右手骨骼，瞄准时指向目标，ShotFlash 与真实弹丸起点一致。tracer 只绘制扫掠实际经过的路径，寿命结束清理。

整图 9 个区域各为独立 .tscn，地基为 CSGPolygon3D、建筑为 MeshInstance3D + StaticBody3D/CollisionShape3D。tools/build_space_city2.py 和 upgrade_operator_v5.py 为离线作者工具，人工编辑后不要重跑覆盖。整图和输入来源 JSON 打入导出包，证据图片不打入包。


## 显示比例与三敌人调度

scenes/ui/display_settings.tscn 与 scripts/display_settings.gd 拥有画面比例：默认 1600×900、KEEP 保持 16:9；4:3 模式使用 1200×900、IGNORE 拉满窗口。UI 设计坐标为 1600×900，Root 在 4:3 模式反向补偿界面宽度。两种模式共用 screen_relative 原始鼠标输入，不修改校准系数。显示选择保存在 user://settings.cfg 的 display/mode；旧配置缺少字段时选择 16:9。

01_peek_squad.tscn 的 peek_squad.gd 继承通用关卡，拥有整波调度。敌人每轮独立随机选择四种动作；同步轮同一时刻起步，错峰轮各有不同延迟。整组三人全部倒地才补充下一波，复用保存的出生变换和导出参数。原 01_peek_lab.tscn 仅用于历史单掩体回归，不是主菜单入口。


## 陪伴培养与路线执行契约

人格配置、长期记忆、当前情绪分别保存和使用。mind 的偏好记录包含值与玩家原话来源；客户端直接识别明确偏好，模型通过 learn_preference 补充语义理解。模型更新必须通过字段白名单、枚举值和本轮原话校验；可在培养页重置。长期自由记忆仍由 propose_memory 提议、玩家明确确认后保存。旧版 companion.json 不含 mind 时使用默认值。

三种人格为温柔陪伴、活泼搭档、沉静教练，共用已配置的本地或云端基础模型；不是三套重新训练的权重。情绪为角色表现，强度随时间回落。没有模型时，原生客户端继续提供标记为本地陪伴的有限回应和全部路线功能。模型就绪检查必须验证实际元数据和对话能力，不能只因模型清单存在就宣称权重可用。

CompanionRoutes 拥有候选和活动路线；主会话拥有真正的关卡加载与成绩记录。plan_training 只准备候选，玩家在路线页选择后开始。客户端不接受模型给出的任意资源路径或运行指令；候选的关卡、装备和目标从同一 TRACKS 定义投影。当前明确训练要求优先于模型猜测。路线默认15分钟三段，可调整总时长3至30分钟；到时仍保持当前关，右下气泡给15秒Y/N选择。超时或N继续当前关，只有Y才能进入下一段；聊天和暂停不消费确认输入，暂停冻结计时，手动换关取消路线。

路线模式复用原关卡、运动和武器，主会话不弹普通定时结果屏。确认换段时把这一段真实统计写回原训练历史，每段最多记录一次；最后一段确认完成后保留当前关自由练习。训练偏好观察读取最近已结算历史的累计时长，是可更改的推荐依据，不能据此断言心理状态或训练迁移效果。

明确路线请求由客户端本地工具即时生成候选，避免把基础操作绑在模型延迟上，来源必须标明本地工具。服务的plan_training仍提供受限模型调用路径及意图调度保底；routed_tools明确标记由调度器补执行的调用。发送模型的训练历史只含统计字段，逐帧证据和指纹留在原本地存档。

### 对话操作适配器

`companion_actions.gd`拥有口语关卡名/别名到main.LEVELS索引的映射、目标追问和执行回执。明确的关卡命令不等待模型；目标不明先询问，90秒内下一句可补全，否定和讨论不执行。支持换关、上一/下一关、路线开始/暂停/继续/停止、下一段及回大厅。切换调用原start_session；实际中断训练写入原始统计，不伪造成功；每段一次记录规则仍有效。开始前关闭聊天层恢复控制，执行后通过现有麦小鼠气泡反馈。

语义模型可调用read_levels读取实际目录，switch_level只提交有效索引给客户端，服务返回pending_client_execution。客户端校验整数范围并真正加载，再显示结果，不能把模型一句“已切换”当操作。last_execution记录ok、tool、origin和实际目标；本地规则与模型提出的调用分别标记。普通聊天可排队，明确操作优先取消旧推理；客户端断开会取消服务端对应模型请求。


### 本地模型事实与启动边界

普通短聊不附带整套工具定义；换关与统计请求只暴露相关工具。模型只承诺换关却没有调用时，服务要求补齐实际调用，不能直接把承诺展示为完成。对上一轮单一有效关卡提问的明确“是的”可作为确认；否定和不同目标不授权操作。无已结算训练记录时由read_training的本地回执说明无法评价，source标为local，不伪装模型生成。

本地Ollama可启用verifyReplies的有限事实审核。审核与角色生成分离，拒绝未提供的个人信息、过去记忆和训练断言；最多两次重写，仍不能确认则返回标为local的诚实保底，不能冒充连接故障。它不是完备的事实证明器。完整GPU运行时、模型、上下文与预热由私人配置决定；模型权重和私人配置不随移动包发布。start.ps1按配置URL启动指定回环端口，预热不依赖云端。

本机服务请求前用短TCP探测识别失联，避免把未监听端口等同于慢模型而等待50秒；模型生成仍保留较长冷加载超时。探测使用请求epoch，命令抢占后旧探测不得继续提交请求。
