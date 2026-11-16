---
name: rhino-moi-pipeline
description: Transfer active Rhino geometry through a protected Rhino 5 working copy and MoI FBX to Blender or Cinema 4D, retaining source state, target-specific identity and hierarchy, custom normals and scale verification. Use for end-to-end Rhino to MoI handoffs, not target-only editing.
---

# Rhino → MoI pipeline

Choose the requested target before loading target documentation. If it is unspecified and cannot be inferred, ask for Blender or Cinema 4D before application operations.

- **Blender**: read [Blender contract](references/blender-target.md) and [workflow](references/blender-workflow.md). Requires Blender MCP and external `blender-playbook`; load that Skill for operations. Follow the linked operation, cleanup and normal-review documents when reaching those stages. Load [preview materials](references/preview-materials.md) only when supplied appearance references/assets activate that stage.
- **Cinema 4D / C4D**: read [C4D contract](references/c4d-target.md) and [workflow](references/c4d-workflow.md). Load external `c4d-remote-executor` before C4D operations; stop if unavailable. All probes, backups, Undo-protected changes and independent acceptance use that dependency.

Both routes read [shared Rhino/MoI gates](references/rhino-moi-common.md) and [metadata bridge](references/rhino-metadata-export.md) before export. Working-copy instructions are loaded for the selected target only. The bundled metadata exporter is internal, with no separate metadata Skill dependency. Runtime evidence and model artifacts belong outside this Skill.

Preserve active source geometry, selection, document identity/path and modified state. Stop on failed or ambiguous evidence; a timeout after a side effect is unknown completion and requires inspection before retry. Never weaken target checks or use order as identity. Retain the distinct C4D `RHINO_ID_`/original MoI route and Blender `RB_`/occurrence route until real regression evidence supports further unification. Shared settings do not establish that one FBX has been verified for both targets.

For requested C4D experience capture or maintenance, read only [queue rules](improvements/RULES.md) before recording. Existing personal pending entries are outside this package. Do not search pending entries or promote a candidate without explicit maintainer review.

See [validation and merge evidence](VALIDATION.md) for offline test scope and remaining application checks.
