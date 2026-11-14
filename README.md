# Rhino → MoI → Cinema 4D 流程 Skill

这是一个用于安全执行 Rhino 7 → Rhino 5 → MoI FBX → Cinema 4D 交接流程的 Codex Skill。它会以只读方式导出 Rhino 元数据，通过 MoI 传递几何，并依据经过验证的空间证据，在 Cinema 4D 中重建 Rhino 的 Layer 或 Block 层级。

## 包含内容

- 完整的流程编排说明和验证关卡。
- 基于 Rhino COM 与 Rhino IronPython 的内置 Rhino 元数据导出器。
- 可复用的 Cinema 4D 场景探针和等数量 Layer 重建逻辑。
- 关于 MoI 导出、几何匹配、异常恢复、产物收束和最终验收的参考文档。
- 由维护者审核的改进候选队列，用于沉淀真实流程验证后获得的通用经验。

通用的 [`c4d-remote-executor`](https://github.com/Purextreme/C4D_remote_script_bridge) Skill 是本流程必需的外部依赖。所有 Cinema 4D 场景探测、修改、恢复检查、预览和验证操作都必须通过它执行。

## 仓库结构

仓库根目录就是 Codex Skill。入口为 [SKILL.md](SKILL.md)，脚本、参考资料和离线测试分别位于 [scripts/](scripts/)、[references/](references/) 和 [tests/](tests/)。

## 安装与维护

首次安装时，先安装 [c4d-remote-executor](https://github.com/Purextreme/C4D_remote_script_bridge) 并按其说明配置 Cinema 4D 插件。目标目录尚不存在时，直接克隆到 Codex 的 Skills 目录。

~~~powershell
git clone https://github.com/Purextreme/rhino-moi-c4d-pipeline.git "$env:USERPROFILE\.codex\skills\rhino-moi-c4d-pipeline"
~~~

在此目录编辑、测试和提交。新开 Codex 会话后可调用 `$rhino-moi-c4d-pipeline`。改进候选留在本机的 [改进队列](improvements/RULES.md) 中。

## 适用范围

本 Skill 适用于完整的 Rhino → MoI → C4D 几何交接和层级重建。普通的 C4D 单独操作应直接使用 `c4d-remote-executor`。

该流程会主动拒绝存在歧义的层级重建。每个模型都必须重新探测；对象顺序、自动生成的名称、坐标轴映射、对象数量和匹配阈值都不能直接继承为下一次任务的身份依据。
