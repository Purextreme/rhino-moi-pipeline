# Shared Rhino / MoI gates

## Branch boundaries

Share the metadata schema/exporter, launcher, safety gates, meshing values and artifact rules. Load only the selected target's workflow. These shared rules do not establish that the same FBX has been tested for both targets.

| Stage | Cinema 4D | Blender |
|---|---|---|
| Working copy | Retain [original C4D copy and Block expansion procedure](c4d-rhino-working-copy.md); ambiguous equal-count Layer route can stamp `RHINO_ID_` | Retain [occurrence copy](blender-rhino-working-copy.md), version 2 sidecar and `RB_` tokens |
| MoI | Original interactive path, including extra slider reference check | Verified-build batch using occurrence manifest, or interactive fallback |
| Matching | Existing BBox/Hungarian/material tie-break, source-ID route, Block and material-split procedures | Existing token occurrence grouping, scale/mapping/containment gates |
| Acceptance | Remote Executor, Normal Tags, backup/Undo and independent readback | MCP/playbook, separate Scene, Empty graph, cleanup receipt and normal review |

Do not replace either matcher, force one naming protocol onto both, pass the Blender occurrence-only batch launcher a C4D transport, or claim cross-target FBX validation without real application regression. The reusable C4D rebuild remains equal-count Layer-only; Block/split cases require its guarded task-specific procedure.

## Preflight and snapshot

Require exactly one Rhino 7 process; never close instances automatically. Capture the active document runtime serial number, path (possibly absent), modified flag, units, selection and semantic metadata. Export through [the shared bridge](rhino-metadata-export.md) before optional Block expansion. Match response and metadata request IDs. Count top-level types and live InstanceReferences, Layers and definitions; choose Block versus Layer from live references, not viewport appearance or unused definitions.

Preserve source geometry, selection, path/identity and initial modified state, including initially modified or unsaved documents. Never save the source or reset `Modified` to pass a check. A disk read is suitable only if it represents this snapshot; otherwise copy the loaded state. Capture target file/document/Scene inventories and protection evidence using the selected target dependency. Keep baseline evidence in task state; model-specific files live outside the Skill.

At acceptance export fresh metadata and compare semantic document, object, Layer and definition records, excluding request-specific automation fields. Check selection separately because it is not a metadata schema field. Equal counts or an unchanged path alone cannot prove source preservation.

## Rhino 5 transport checks

The following full-file scope recovery procedure applies to C4D's original copy route. Blender's occurrence generator instead builds a new File3dm from snapshot objects and validates the version 2 sidecar, exact occurrence count/tokens and transformed geometry; its fresh transport IDs must not equal original source IDs.

In Rhino 7, `doc.Write3dmFile` and the active document's object enumeration need not expose the same object set. A full file copy can include hidden or otherwise unenumerated objects, plus unused definition members. A count assertion failure does not establish invalid geometry or a failed write.

Before opening the copy in MoI:

1. Reopen the existing copy as a `File3dm`. For each file object use `item.Attributes.ObjectId`; `ObjectAttributes` does not expose the Rhino document object's `Id` property. Exclude `Attributes.IsInstanceDefinitionObject` when comparing top-level objects, and keep definition records separate.
2. Compare the complete top-level ID set with the current metadata's `objects[*].id`, not just its size. Inspect missing and extra objects by ID, type, mode, layer, and definition membership. Do not label every extra object as hidden, deleted, or historical without evidence.
3. Establish the intended conversion scope. If the metadata represents that scope, filter only a separate in-memory `File3dm` to those top-level IDs and write a new, distinct transport file. Keep the full copy and source intact. Retain definitions needed by live instances. If an excluded object belongs in the requested model, obtain a metadata snapshot covering it before conversion instead of silently dropping it.
4. Reopen the new transport file and require exact top-level ID-set equality, valid supported geometry, valid layer references, and unchanged source identity and modified state. For expanded Block copies, validate occurrence keys and the expansion manifest instead of requiring original instance IDs on newly created geometry.

An existing nonzero output may come from a completed file write: reopen and validate it before retrying. File existence or size alone does not establish success. Repair a failed response or validation separately; never overwrite an existing conversion file merely because the response failed.

Choose Layer versus Block reconstruction from live top-level instance references. An unused definition table does not make the transport a Block assembly.

Require supported valid geometry, valid Layer references and standalone object modes. Normalize only copies of definition members to Normal/visible as prescribed by the branch; preserve source visibility and locking in reconstruction metadata. Use transformed geometry to measure occurrence BBoxes; transformed definition-box corners can overestimate rotated shapes. Multiply transforms outer-to-inner and detect cycles on the current recursion path, allowing repeated instances.

Keep source identity/modified state and semantic geometry unchanged after writing. The Rhino 5 file, sidecar (Blender) and automation response are separate commit points. Nonzero output with a failed response requires inspection/recovery, never blind overwrite or rerun. Serialize ASCII-safe responses before publication. Use a separate byte-identical ASCII staging copy if MoI cannot handle a Unicode path; keep the original source-side copy.

## Common MoI preset

Open only the validated Rhino 5 transport and inspect expected geometry after loading. An empty view requires checking validity, counts, visibility and standalone modes before another export. Preserve the existing interactive MoI document.

| Setting | Value |
|---|---|
| Output | N-gons |
| Display | Shaded + edges |
| Weld vertices along edges | Checked |
| Angle | 3 |
| Divide larger than | 20, All |
| Avoid smaller than | 0.5 |
| Aspect ratio limit | 0 |

Lengths use MoI document units; these are tessellation settings, not geometric-error guarantees. Inspect small, thin and curved geometry. Preview point/polygon counts are diagnostic and can include render/normal splits; require each target's object-level import checks. Require a fresh, nonzero FBX with an ASCII-compatible filename.

C4D additionally checks the polygon slider against the approved high-detail reference on site, then visually verifies every settled dialog value. Blender retains the [verified-build batch and dialog fallback](blender-workflow.md#moi-meshing), including token manifest, build hash and completion/header checks. C4D slider evidence is not implied by Blender API option strings. Do not generalize the verified Blender build to C4D or to a changed MoI executable.

## Artifact consolidation

ASCII staging is a transport workaround, not the final delivery location.

1. Resolve and verify the exact staging and source-side destination paths.
2. Use `<original model folder>\codex_export_fbx` as the default final artifact directory unless the user specifies another location. If the source has no saved path, use the current task's writable output directory and report that destination; do not guess a source directory from an application title or an unrelated recent file.
3. Move the FBX and any other unique process artifacts into that directory.
4. If the destination already contains a same-named Rhino 5 or FBX file, compare SHA-256 before cleanup. Delete the staging duplicate only when hashes match; never overwrite a different file.
5. Re-list the destination and record file sizes and hashes.
6. Remove the staging directory only after proving it is empty. Avoid recursive deletion for this cleanup.
7. Report the final paths. If the open C4D document was loaded from the former staging path, clarify that future reimports must use the consolidated FBX path.


Keep metadata, transport, sidecars/manifests, plans, cleanup receipts and retained protection copies under distinct filenames. Preserve hashes and current request provenance. Blender additionally relocates manifest/plan/cleanup paths and repeats verification as described in its [consolidation section](blender-workflow.md#final-artifact-consolidation). C4D retains its source-ID/full-copy evidence and reports an old import path if applicable. Final native target saves follow the selected target's user-authorized destination rules.
