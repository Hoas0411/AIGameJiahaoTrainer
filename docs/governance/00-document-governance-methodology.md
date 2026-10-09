# 北极星-19 — 文档治理通用方法论

> 最后更新：2026-06-28  
> **状态**：canonical  
> **真相域**：doc_order（通用抽离版；不新增 Lumi 内部 owner）  
> **定位**：从 Lumi 文档体系抽离出的跨项目 DocOps 方法论；用于新项目建立 docs 控制面、LLM 记忆中心和可验证的文档秩序。  
> **上位**：[00-宪法](00-宪法.md) · [05-文档整理判据](05-文档整理判据.md) · [06-顶级规划图与真相源](06-顶级规划图与真相源.md) · [07-DocOps与LLM记忆中心](07-DocOps与LLM记忆中心.md) · [10-顶级读法入口](10-顶级读法入口.md) · [北极星-18](北极星-18-文档分层与治理模型.md) · [理念-27](../design/理念-27-语义理念与顶层架构.md)  
> **不覆盖**：不替代 10 的日常七步链，不替代北极星-18 的 Lumi 内部分层模型，不替代 07 / `docops-rhythm.yaml` 的运行节奏，不替代 09 / `lumi-state.yaml` 的当前状态。  
> **适用对象**：任何长期演进、多人/多 Agent 协作、需要 LLM 接手上下文的项目。

---

## 0. 一句话

> **文档治理不是整理资料，而是给项目建立控制面：窄入口、单真相、分层投影、状态账本、证据链、机器门。**

如果只记一句：

```text
理念定方向，架构定房间，施工整理房间，证据验房间；入口负责带路，状态只写账本。
```

Lumi 这套 docs 的核心不是“文档很多”，而是“人和 LLM 都能稳定判断该读哪篇、信哪篇、改哪篇、何时过期”。

---

## 1. 从 Lumi 抽离出的七条原则

| 原则 | 含义 | 反面 |
| --- | --- | --- |
| **docs 是控制面** | 文档负责方向、边界、真相源、当前状态和证据索引 | 把 docs 当资料堆、会议纪要仓库 |
| **文档治理也是语义治理** | 每个概念、状态、动作、完成定义都要有唯一 owner | 同一个词在 README、prompt、代码、UI 各说各话 |
| **SSOT 不是巨型文档** | 一个真相域一个上游；下游只链接、投影、验收或过期 | 把所有内容塞进一篇“总文档” |
| **入口比厚度重要** | 给人和 LLM 一条日常读链；链外默认降权 | 靠全文搜索随机撞答案 |
| **状态和理念分离** | 长期理念进北极星/SSOT；当前状态进 09 / yaml；证据进 inspection | 在长期文档里写进度、PASS、百分比 |
| **聊天不是事实源** | 关键裁定当天落到正式真相源、状态账本或草稿池 | “上次我们聊过”成为唯一依据 |
| **机器门替人记纪律** | 链接、truth registry、状态漂移、语义投影、文风禁词都可检查 | 只靠团队记忆维护文档秩序 |

这套方法的目标不是让项目显得规整，而是减少三类事故：

1. LLM 接手时读错旧文，把历史当当前法。
2. 人改文档时复制第二份真相，半年后互相打架。
3. 代码、UI、prompt、文档对同一事实有不同解释。

---

## 2. 标准分层：三层主干 + 一层证据

新项目不必一开始复制 Lumi 的完整 00–10 金字塔。先建立四层轻模型：

```text
L0 理念 / 法律 / 北极星
  = 为什么做、绝对不能做什么、最高抽象目标

L1 架构 / 边界 / 契约
  = 系统有哪些房间、门、总线、真相源、标准链

L2 组织 / 施工 / 房间内部
  = 当前怎么改、分几步、谁负责、哪些债要退役

L3 证据 / 状态 / 体检 / 记录
  = 现在做到哪、哪条红、哪条绿、是否签收
```

| 层 | 放什么 | 不放什么 |
| --- | --- | --- |
| L0 | 产品使命、原则、红线、长期不可变抽象 | 本周排期、测试结果、临时争议 |
| L1 | SSOT、架构图、协议、数据模型、模块边界 | “下一刀”、完成百分比、现场日志 |
| L2 | roadmap、施工单、迁移计划、退役计划 | 新哲学、新协议、长期字段定义 |
| L3 | 状态面板、验收记录、回归样本、事故复盘 | 反向改写理念、替代 SSOT |

裁判顺序：

```text
先问 L0 是否合宪
  → 再看 L1 是否有边界和标准链
    → 再让 L2 按锁区施工
      → 最后用 L3 证明是否过
```

---

## 3. 一个疑问词一个 owner

每篇长期文档都必须回答一个主要疑问词。答两个，就拆。

| 疑问词 | 文档类型 | 例子 |
| --- | --- | --- |
| 为什么 | 灵魂 / 宪法 / 北极星 | 产品为什么存在、长期相信什么 |
| 不能做什么 | 法令 / 边界 | 安全、权限、外发、写入红线 |
| 是什么 | SSOT / 规范 / 契约 | API、schema、状态机、UI 协议 |
| 词是什么意思 | 词典 / 语义台账 | 标准名、别名、碰撞词 |
| 信哪篇 | 真相源地图 | owner、下游、冲突处理 |
| 从哪读 | 读法入口 | 人和 LLM 的启动链 |
| 现在到哪 | 状态面板 / yaml | 当前进度、下一步、缺口 |
| 怎么干 | 施工单 / roadmap | 阶段、门槛、验收步骤 |
| 过没过 | inspection / record | PASS/FAIL、样本、证据 |
| 当时为何这样 | ADR / archive | 历史上下文，不改写 |

最小判断尺：

```text
它三个月后还成立吗？
成立：放 L0 / L1。
不成立：放 L2 / L3。

它是在定义应该怎样，还是证明已经怎样？
定义：SSOT / 规范。
证明：inspection / evidence。
```

---

## 4. 真相域：不要让文档互相抢权

每个项目都应该有一个 `truth-registry` 或同类台账。它不需要复杂，先能回答四列：

| 字段 | 含义 |
| --- | --- |
| `domain` | 这类真相叫什么 |
| `owner` | 唯一上游是哪篇 |
| `answers` | 它只回答什么 |
| `downstream` | 哪些文档、代码、prompt、UI 只消费它 |

示例：

```yaml
truth_domains:
  project_macro:
    status: canonical
    owner: docs/00-north-star/08-project-macro.md
    answers: 项目身份、路线、顶层抽象、边界轴
    downstream:
      - docs/README.md
      - AGENTS.md

  current_state:
    status: active
    owner: docs/00-north-star/09-command-center.md
    coowners:
      - docs/_meta/project-state.yaml
    answers: 当前进度、下一刀、缺口、证据索引
```

冲突处理规则：

1. owner 正文压过 downstream 摘要。
2. canonical / active 压过 draft / archive。
3. SSOT 压过施工单；施工单只记录如何追上 SSOT。
4. 状态面板压过旧 roadmap 的“下一步”。
5. inspection 只证明某次过没过，不能单次反向改理念。

---

## 5. 推荐目录骨架

小项目先用轻量版：

```text
AGENTS.md
README.md
docs/
  00-north-star/
    00-constitution.md
    05-doc-order.md
    06-truth-map.md
    07-docops.md
    08-project-macro.md
    09-command-center.md
    10-read-entry.md
  design/
    SSOT-*.md
    spec-*.md
  roadmap/
    decision-*.md
    construction-*.md
  inspection/
    record-*.md
  _meta/
    truth-registry.yaml
    docops-rhythm.yaml
    project-state.yaml
  _draft/
  _archive/
  DOCS_CHANGELOG.md
```

大项目再扩展：

```text
docs/design/
  agent/
  data/
  product/
  ui/
```

不要一开始就搬目录。先把权威关系、入口链、状态账本和机器门立住。物理分目录只有在找文档成本明显上升、同域 owner 过多、LLM 连续读混时再做。

---

## 6. LLM 记忆中心：给模型读“控制面”，不是读全库

一个可持续的 LLM docs 体系至少要有四类上下文包：

| 包 | 默认内容 | 用途 |
| --- | --- | --- |
| `project_boot` | AGENTS、README、读法入口、宏观认知、状态面板、truth registry | 每次接手先装坐标 |
| `docs_governance` | 文档分层、真相源、DocOps、归档规则 | 整理 docs、删冗、升格 |
| `domain_work` | 当前任务的 SSOT、施工单、相关代码入口 | 做具体实现 |
| `evidence_review` | inspection、回归样本、测试脚本、事故记录 | 验收、复盘、判断是否真的过 |

核心纪律：

1. 先读入口和状态，再读任务域 SSOT。
2. 不让 LLM 从 `_archive` 或旧施工单直接开工。
3. prompt / skills / context 分轨，不能把设计文档全文塞进模型当规则。
4. 让 LLM 知道“该信哪篇”，比让它读更多文档更重要。

---

## 7. 状态、施工、证据三分

这是文档治理最容易翻车的地方。

| 内容 | 应放 | 不应放 |
| --- | --- | --- |
| 当前做到哪、下一刀、缺口 | `09-command-center.md` + `project-state.yaml` | SSOT、北极星、README 长段落 |
| 某功能怎么落地 | `roadmap/construction-*.md` | 宪法、宏观认知 |
| 某次测试过没过 | `inspection/record-*.md` | 长期协议 |
| 某个协议是什么 | `design/SSOT-*.md` | 施工单正文 |
| 临时讨论 | `_draft/` 或短施工记录 | 根目录散文、聊天唯一记忆 |

长期文档如果出现这些词，要警惕：

```text
今天 / 明天 / 本周 / 下一刀 / 已完成 70% / PASS / FAIL / 待真人签收
```

它们通常应该移到状态面板、施工单或 inspection。

---

## 8. 文档生命周期

文档状态建议固定为六种：

| 状态 | 含义 | 规则 |
| --- | --- | --- |
| `canonical` | 当前唯一真相源 | 可改，但要同步下游 |
| `active` | 当前施工或执行文档 | 可改，过期后降权 |
| `draft` | 未签字草稿 | 不可被当权威引用 |
| `snapshot` | 验收、审计、事故快照 | 原则上不改写，只补勘误 |
| `redirect` | 旧名跳转 | 只保留跳转 |
| `retired` | 已归档 | 只解释历史，不指导新实现 |

升格、归档、删除规则：

| 情况 | 动作 |
| --- | --- |
| 草稿被反复引用 | 升格到正式目录，补状态、上位、不覆盖、链接 |
| 施工单开始定义长期协议 | 抽到 SSOT，施工单只留阶段和验收 |
| SSOT 里写进度 | 迁到 09 / yaml / roadmap / inspection |
| 两篇文档回答同一问题 | 保留上游，另一篇改 redirect、摘要或 archive |
| 旧施工单口径危险 | 标 `historical` / `superseded`，加现行入口 |

新开文档五问：

1. 它回答的唯一疑问词是什么？
2. 它的上位真相源是哪篇？
3. 它会不会过期？
4. 它覆盖哪一篇，还是只是下游投影？
5. 它的验收事实放在哪里？

五问答不清，先放 `_draft/`。

---

## 9. 机器门：从第二周开始就要有

最小机器门：

```powershell
py docs/check_doc_links.py --check
py docs/check_truth_registry.py --check
```

成熟后补：

| 检查 | 防什么 |
| --- | --- |
| link check | 死链、旧名、移动后断引用 |
| truth registry check | 同域多 owner、路径不存在、状态非法 |
| state drift check | README、09、yaml、roadmap 状态漂移 |
| stale check | 施工单、裁定超过复审周期仍当当前法 |
| draft/archive check | canonical 文档引用草稿或归档当权威 |
| prose lint | 过期词、空泛完成话术、混称 |
| semantic projection check | 词典、UI、工具、prompt、测试投影不一致 |

机器门的目标不是制造流程，而是把团队最容易忘的纪律交给脚本。

---

## 10. 新项目落地节奏

### Day 0：先立四件事

1. `AGENTS.md`：告诉 LLM 进场先读什么、禁止什么。
2. `README.md`：只做入口，不写成百科。
3. `10-read-entry.md`：日常读链。
4. `09-command-center.md` + `project-state.yaml`：当前状态和下一刀。

### Week 1：补齐控制面

1. `00-constitution.md`：项目信什么、最高红线是什么。
2. `05-doc-order.md`：每类文档回答什么。
3. `06-truth-map.md` + `truth-registry.yaml`：信哪篇、谁覆盖谁。
4. `07-docops.md` + `docops-rhythm.yaml`：维护节奏和 LLM context packs。
5. `DOCS_CHANGELOG.md`：每次文档结构变化记一笔。

### Month 1：开始减重和机器化

1. 把重复的长期正文抽成 SSOT。
2. 把施工进度从 SSOT 迁到 09 / roadmap。
3. 把旧文档标为 historical / retired。
4. 接入链接检查、truth registry 检查、状态漂移检查。
5. 为 LLM 常用任务定义 context pack。

---

## 11. 红灯反模式

| 反模式 | 为什么危险 | 正路 |
| --- | --- | --- |
| README 变百科全书 | 入口变厚，没人知道信哪段 | README 只导航 |
| 一个巨型 SSOT 管所有事 | 多个疑问词抢同一篇 | 按 truth domain 拆 owner |
| 施工单写成永久法律 | 过期后继续裁判 | 长期协议抽到 SSOT |
| 状态散落在聊天和 root note | LLM 接手读不到，团队记忆漂移 | 状态进 09 + yaml |
| inspection 反向改理念 | 单次样本过拟合成哲学 | 多样本后再改 L0/L1 |
| archive 被现役文档当依据 | 旧法回流 | 链外旧文默认 historical |
| 搬目录顺手改语义 | 无法判断是迁移还是改法 | 搬家和改义分两次 |
| prompt 复制 docs 全文 | LLM 上下文膨胀且过期 | context pack + 摘要投影 |
| 文档只靠人维护 | 三个月后必漂 | 最小机器门早接入 |

---

## 12. 可复制模板

### 12.1 长期文档文首

```markdown
> 最后更新：YYYY-MM-DD
> **状态**：canonical | active | draft | snapshot | redirect | retired
> **真相域**：truth-registry.yaml 里的 key
> **定位**：本文只回答什么
> **上位**：...
> **不覆盖**：...
> **下游投影**：...
> **复审节奏**：weekly | monthly | per-phase | immutable
```

### 12.2 施工单文首

```markdown
> **状态**：active
> **权威对照**：上位 SSOT / decision
> **施工目标**：本次只改什么
> **不改**：哪些边界不碰
> **过期条件**：何时降权或归档
> **验收门**：测试 / inspection / 手工签收
```

### 12.3 inspection 记录文首

```markdown
> **状态**：snapshot
> **样本 / 环境**：...
> **结论**：PASS | FAIL | WARN
> **证据**：命令、日志、截图、Flight、测试输出
> **不裁判**：本文不改长期理念，只证明这次结果
```

---

## 13. 和 Lumi 当前文档的关系

本文是“抽离版”，用于别的项目复用。Lumi 内部仍按现行链路裁判：

| 问题 | Lumi 内部信哪篇 |
| --- | --- |
| 日常怎么读 | [10 §1 七步链](10-顶级读法入口.md#1-日常七步链串起来读) |
| 文档怎么分层 | [北极星-18](北极星-18-文档分层与治理模型.md) |
| 每个板块该不该拆 | [05](05-文档整理判据.md) |
| 信哪篇、谁覆盖谁 | [06](06-顶级规划图与真相源.md) |
| docs 怎么持续维护、喂给 LLM | [07](07-DocOps与LLM记忆中心.md) |
| 当前状态和下一刀 | [09](09-总控状态面板.md) + [`lumi-state.yaml`](../_meta/lumi-state.yaml) |
| 旧施工单怎么降权 | [审计-98](../roadmap/审计-98-施工文档归位审计.md) |

如果未来把这套方法迁移到新项目，不要照搬 Lumi 的所有编号和术语。照搬的是治理结构：

```text
入口窄
真相单
状态活
证据硬
旧文降权
机器守门
LLM 按包读
```

---

## 14. 修订记录

| 日期 | 变更 |
| --- | --- |
| 2026-06-28 | 初版：从 Lumi 05 / 06 / 07 / 10 / 北极星-18 / 理念-27 抽离跨项目文档治理方法论 |
