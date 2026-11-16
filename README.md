# Rhino → MoI → Blender / Cinema 4D

用于 Codex 的 `rhino-moi-pipeline` Skill 可将当前 Rhino 几何经受保护的 Rhino 5 工作副本、MoI FBX，交接到明确选择的 Blender 或 Cinema 4D，按目标规则保留对象身份、重建层级，并检查自定义法线和物理比例。

## 依赖

- 公共环境：Windows、PowerShell，以及已打开的 Rhino 7、MoI 和所选目标应用。MoI 对话框操作需要 Computer Use，或经当前版本验证的应用脚本接口。Rhino 元数据导出器已内置，无需额外安装元数据 Skill。
- **Blender**：已连接的 Blender MCP，以及外部 `blender-playbook` Skill。
- **Cinema 4D / C4D**：外部 [c4d-remote-executor](https://github.com/Purextreme/C4D_remote_script_bridge) Skill，并按其说明配置 Cinema 4D 插件。所有 C4D 探测、备份、Undo 保护下的修改和独立验收均通过它执行，依赖不可用时停止。

这是 Skill 与辅助脚本包。仅需安装所选目标的依赖。单独操作目标应用时应使用相应操作 Skill。

## 安装与使用

在 PowerShell 中运行以下命令，将统一仓库克隆到 Codex 的 Skills 目录。目标路径已存在时直接停止，请先检查现有内容和本地修改。

```powershell
$skillsRoot = Join-Path $env:USERPROFILE '.codex\skills'
$targetDirectory = Join-Path $skillsRoot 'rhino-moi-pipeline'
if (Test-Path -LiteralPath $targetDirectory) {
    throw "目标路径已存在，请先检查，勿覆盖：$targetDirectory"
}
if (-not (Test-Path -LiteralPath $skillsRoot)) {
    New-Item -ItemType Directory -Path $skillsRoot -ErrorAction Stop | Out-Null
}
git clone https://github.com/Purextreme/rhino-moi-pipeline.git "$targetDirectory"
if ($LASTEXITCODE -ne 0) { throw '克隆失败，请检查 Git 输出' }
```

新开 Codex 会话，明确指定目标，任选一种调用。

```text
使用 $rhino-moi-pipeline，目标为 Blender，把当前 Rhino 模型经 MoI 导入已打开的 Blender。
```

```text
使用 $rhino-moi-pipeline，目标为 Cinema 4D，把当前 Rhino 模型经 MoI 导入已打开的 Cinema 4D。
```

未指定且无法推断目标时，先确认目标再操作应用。Blender 如需简单预览材质，可同时提供外观参考图、商品链接或本地贴图。仅在提供参考或资产时启用该阶段。

## 范围与目标差异

- 保留 Rhino 源几何、选择、文档身份与路径、修改状态。运行证据和模型产物放在 Skill 目录之外。
- Blender 保留 `RB_` / occurrence 身份路线，按目标流程重建图层及嵌套块层级，进行缩放、轴心和法线复核。预览材质按需执行。
- C4D 保留 `RHINO_ID_` / 原有 MoI 路线，按 C4D 的对象级证据执行 Layer 或 Block 层级重建。
- 证据失败或有歧义时停止。对象身份以每个对象的证据为准。产生副作用后超时视为完成状态未知，检查后才能重试。两个目标分别验收各自的 FBX。

仓库提供 Skill 结构检查、桥接协议与启动器测试、Cinema 4D 对应关系的离线测试，以及 Blender 后台 FBX 回归测试。

## 相关文档

- [统一入口与约束](SKILL.md)、[Rhino / MoI 公共关卡](references/rhino-moi-common.md)、[元数据桥接](references/rhino-metadata-export.md)。
- Blender：[目标约定](references/blender-target.md)、[完整流程](references/blender-workflow.md)、[工作副本](references/blender-rhino-working-copy.md)、[操作边界](references/blender-operations.md)、[后处理](references/post-processing.md)、[预览材质](references/preview-materials.md)。
- C4D：[目标约定](references/c4d-target.md)、[完整流程](references/c4d-workflow.md)、[工作副本](references/c4d-rhino-working-copy.md)。
- [改进队列规则](improvements/RULES.md)：按请求记录 C4D 经验或维护候选，通过维护者审核的条目才可纳入共享规则。
