# End-to-end workflow

## 1. Preflight and metadata

Load `c4d-remote-executor` and inspect open C4D documents. Follow [shared preflight and snapshot](rhino-moi-common.md#preflight-and-snapshot) and [metadata bridge](rhino-metadata-export.md). Retain the metadata request ID for later artifacts.

## 2. Rhino 5 copy

Read [c4d-rhino-working-copy.md](c4d-rhino-working-copy.md) before preparing the conversion copy. Select the export from the actual source state: a disk read is suitable only when it represents the metadata snapshot; an unsaved or modified document needs a copy of the loaded state. Refuse overwrite and verify the original runtime serial number, path, and modified state after writing. An initially modified document must remain in that state.

For Block mode, expand occurrences in a separate in-memory `File3dm`, normalize copied object attributes for standalone geometry, and validate the written copy before opening it in MoI. Keep the original Block metadata for reconstruction.

Treat the Rhino 5 file and the automation response as separate commit points. If the file is nonzero but the response is missing or malformed, do not overwrite or blindly rerun the write. Verify the existing file, source path, active path, and modified state; then recover by publishing an ASCII-safe response that marks the output as preexisting.

If MoI cannot open a path containing Chinese characters, make an additional byte-identical staging copy under an ASCII-only absolute path. This is a compatibility copy, not a replacement for the source-side Rhino 5 artifact.

## 3. MoI FBX export

Open the Rhino 5 copy in MoI. When no stable MoI scripting interface is available, use computer control and visually verify every value before confirming.

Wait for loading to complete and inspect the expected geometry before starting export. If the view is empty, inspect the copy's object count, geometry validity, visibility, and object modes before generating another file. Valid geometry can still be excluded because it retains definition-only attributes.

Apply the [common MoI preset](rhino-moi-common.md#common-moi-preset). **C4D extra on-site check:** polygon slider must match the approved high-detail reference. Visually verify every settled value before confirming. Preview counts are diagnostic, not a substitute for the C4D probe.

## 4. C4D import and Normal tags

1. Preserve every previously open C4D document. Load the FBX as a separate document.
2. For scripted loading in C4D 2024, use `SCENEFILTER_OBJECTS | SCENEFILTER_MATERIALS`; `SCENEFILTER_NONE` can return an empty document.
3. Before exposing the document for mutation, probe it and require:
   - polygon-only flat import;
   - a material count consistent with the source/export expectations, including zero when the source genuinely has no materials;
   - one Normal tag on every Polygon;
   - C4D importer behavior equivalent to `Normals: Normal Tags`.
   Use the bundled `scripts/c4d/probe_imported_scene.py` through `c4d-remote-executor` when it fits the current C4D version, injecting an absolute `OUTPUT_PATH`.
4. Before insertion, capture previous-document identity and summaries as ordinary Python values and retain the validated protection backup for any document that must be preserved. After `InsertBaseDocument()`, re-enumerate live documents; do not dereference a stale `BaseDocument` wrapper, which C4D may invalidate.
5. Insert and activate the validated document, then compare the live document inventory with the baseline. C4D can replace its sole empty tab during insertion. If a prior document disappeared, inspect first and restore that exact document from its validated backup when available; re-enumerate and verify it before reactivating the import. Never synthesize a replacement from a zero object/material count or repeat the FBX import to repair a missing tab.

If an exception, empty socket response, or timeout occurs after document insertion or another side effect, classify completion as unknown. Use `c4d-remote-executor` read-only probes and its lifecycle evidence to inspect the active documents before deciding whether any retry is safe.

## 5. Geometry matching

Build exact world BBoxes from C4D polygon points, not only object radii. Generate plausible axis permutations, signs, scale, and translation candidates, then re-derive or directly validate the transform for every scene. A mapping seen in a previous case is only a candidate, never a default.

For Block mode, match expanded geometry occurrences, not unique definition members. Repeated instances need distinct occurrence keys and accumulated transforms. Use BBoxes measured from the transformed geometry in the working copy, and verify the exported occurrence count against the imported geometry count. Controlled export names can cross-check provenance, but do not replace spatial matching or resolve an otherwise ambiguous assignment.

Do not select a transform only from the overall scene bounds: Rhino curves, points, construction geometry, or objects that MoI omits can skew the overall bounds and make a wrong mapping appear numerically better. Require support from multiple object-level correspondences.

For equal counts:

1. Generate all plausible axis permutations/signs.
2. Build the Rhino-to-C4D BBox cost matrix.
3. Use Hungarian assignment.
4. Use material/layer leaf names only inside the geometry ambiguity gap, never as primary identity. Permit the tie-break only when one candidate's C4D material name exactly matches the Rhino Layer leaf and that exact match is unique; otherwise keep the row ambiguous.
5. Record how many assignments the material tie-break resolved and independently verify that each resolved Polygon is under the expected Layer Null with the expected material.
6. Reject excessive maximum error or unresolved equal-cost candidates.

If coincident BBoxes and the material tie-break leave a flat equal-count Layer import ambiguous, use a fresh [source-ID transport copy](c4d-rhino-working-copy.md#carry-source-ids-through-an-equal-count-layer-export). The complete imported token set must match the geometry IDs in the same Rhino metadata snapshot, with each token appearing exactly once. The tokens establish correspondence. Fit one axis permutation, sign combination and translation to the paired world BBoxes and reject any object outside the accepted tolerance. The supplied matcher expects the Rhino and C4D coordinates to be in the same units. If the import introduces a scale change, correct and verify the units before matching.

For `C4D Polygon count > Rhino Brep count`:

1. Globally assign every Rhino Brep to a unique C4D Polygon.
2. Require all Brep assignments to remain under the accepted geometry tolerance.
3. Inspect the unassigned C4D meshes. Face-material splits commonly retain the same source envelope while producing different material tags.
4. Attach a leftover only when its BBox is contained by, or is within an explicitly justified meshing tolerance of, a matched Brep and resolves to one Rhino layer path.
5. Retain the split count and containment tolerance in task state; include them in a case log only when requested.

Curves and points must not be silently treated as Breps. If MoI does not emit corresponding polygons, omit them from geometry matching and preserve the fact in the report.

## 6. Hierarchy mutation

Choose Block or Layer reconstruction from the metadata, not from C4D names.

For an equal-count Layer scene, `scripts/c4d/rebuild_layers_from_rhino.py` is the maintained starting implementation. Inject `METADATA_PATH` and evidence-backed thresholds before sending it through `c4d-remote-executor`. It intentionally rejects Block mode and count differences.

For the verified source-ID import, also inject `USE_SOURCE_IDS = True`. Missing, duplicate or changed tokens and excessive BBox error stop this route before hierarchy mutation. The rebuild restores the source names or the usual Layer-derived names for unnamed geometry.

Before mutation validate the active document name, polygon count, topology, Normal tags, material tags, names, BBoxes, and metadata request ID. Then:

1. save each Polygon `GetMg()`;
2. create `RHINO_METADATA_REBUILT` and the required Null tree;
3. register Undo for new Nulls, hierarchy changes, and renames;
4. `InsertUnderLast()` the Polygon;
5. restore `SetMg()`;
6. rename from Rhino Definition or Layer context;
7. call `c4d.EventAdd()`.

## 7. Acceptance gate

Check the response at both levels. Require top-level `ok`, `execution_ok`, and `verification_ok` to be true. Task scripts must return `_result` with `execution_ok` and `verification_ok`; require `result.execution_ok` and `result.verification_ok` to be true as well. The bridge can successfully execute a script that returns a failed task check, so a zero client exit code or top-level success cannot override that result. Inspect assertions, protection, and warnings before proceeding.

Run an independent read-only probe and retain the following evidence. Summarize relevant results in the conversation; write a separate report only when requested:

- top-level root and direct children;
- total objects, Nulls, and Polygons;
- Normal-tag and material-tag counts;
- remaining `obj*` names;
- hierarchy depth;
- per-object and overall world-BBox errors;
- the unordered per-Polygon topology/geometry signature `(point_count, polygon_count, exact_world_bbox)` before and after hierarchy mutation;
- for source-ID matching, verify each Polygon's restored name and Layer path, and compare world vertex coordinates and face indices before and after mutation within the same FBX import. Separate MoI exports can triangulate differently with the same settings;
- every material-resolved tie-break path and its final material;
- C4D protection backup path/hash when available;
- whether the final document was saved or intentionally left open and unsaved.

The prior C4D documents and the active Rhino source must still exist and remain unchanged.

For the Rhino source, obtain a fresh metadata response and compare the semantic document, object, Layer, and Definition records with the baseline, excluding request-specific automation fields. Verify the separately captured modified state as well. Equal counts alone do not prove that the source remained unchanged.

Render a framed preview when geometry visibility matters. If C4D successfully writes a nonzero preview but the client-side inspector lacks an image dependency, inspect that file with another available image viewer instead of rerunning the scene mutation. Re-probe afterward to confirm any temporary preview camera was removed.

A failed view-framing command is a view-operation failure, not evidence that geometry import failed. Inspect the current view or use the Remote Executor's framed preview. Do not repeat an import or hierarchy mutation to fix framing, and do not claim the view command succeeded without a successful return or visual evidence.

## 8. Artifact consolidation

Follow [shared artifact consolidation](rhino-moi-common.md#artifact-consolidation). If the open C4D document was loaded from the former staging path, future reimports must use the consolidated FBX. Leave the document open for review; save a final `.c4d` only to a user-requested or confirmed destination.

## Stop and request help

Stop instead of accumulating errors when:

- Rhino process count is not exactly one;
- Rhino modified state or active path changes unexpectedly;
- MoI dialogs differ from the approved settings and cannot be interpreted confidently;
- a file dialog corrupts a Unicode path and ASCII staging does not resolve it;
- C4D imports no objects or omits Normal tags;
- geometry counts differ and the leftovers cannot be explained as verified splits or omitted non-mesh objects;
- matching is ambiguous or exceeds the chosen tolerance;
- a script fails after any C4D side effect and a read-only probe cannot establish the resulting state;
- C4D protection fails or a bridge timeout leaves completion unknown;
- final artifacts cannot be consolidated without overwriting a different destination file.
