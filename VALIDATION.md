# Merge and validation evidence

This record covers the Skill consolidation. [The baseline manifest](tests/baseline-sha256.json) records SHA-256 hashes of the 32 source files used for comparison.

## Retained and shared components

- One [Skill entry](SKILL.md) and one [agent definition](agents/openai.yaml), with target-specific loading.
- One metadata serializer (schema 2, retaining `document.modified`), [shared launcher](scripts/rhino-metadata/bridge.ps1) and [dispatcher](scripts/rhino-metadata/bridge_request.py). Both wrappers use request-specific paths, a shared session mutex and structured failure evidence. Runtime bridge evidence is created beside task outputs, outside the Skill.
- [Shared Rhino/MoI gates](references/rhino-moi-common.md) cover snapshot preflight, object-level Rhino 5 scope checks, common preset and hash-safe archival. [Protocol details and recovery limits](references/rhino-metadata-export.md) describe synchronous COM and incomplete publication.
- C4D retains its original copy procedure, `RHINO_ID_` helper, original MoI interactive path and slider checkpoint; equal-count matching, Block handling and material-split procedures stay distinct. Remote Executor dependency, backup/Undo, Normal Tags and independent readback remain mandatory.
- Blender retains `RB_` occurrence/sidecar transport, verified MoI batch and dialog fallback, MCP/playbook, separate Scene and Empty hierarchy, cleanup, custom normals/scale verification, review Collections and conditional preview materials.
- C4D scripts, Blender downstream scripts, all three original tests, MoI batch launcher/job and C4D source-ID helper were compared byte-for-byte with their inputs and are unchanged. The Blender working-copy `main(request)` implementation is unchanged; its fixed-mailbox footer was replaced by shared dispatch. No matcher or identifier protocol was unified.
- [C4D improvement rules](improvements/RULES.md) are retained verbatim. No personal pending entries are included.

## Executed checks

Commands below are relative to this package root. Each C4D test was executed separately with Python, never with unittest discovery.

```powershell
python -B tests/test_layer_mode.py
python -B tests/test_source_id_matching.py
python -B tests/test_bridge_protocol.py
pwsh -NoProfile -File tests/test_bridge_launcher.ps1
blender --background --factory-startup --python-exit-code 1 --python tests/test_post_processing.py
python -B tests/check_package.py
node --check scripts/moi_export_job.js
```

- C4D Layer-mode test: **6/6 passed**; source-ID matching test: **6/6 passed**, without C4D.
- Added dispatcher tests: **5/5 passed**, covering explicit interleaved request paths, current request ID on Unicode failures, traceback/ASCII-safe publication, preservation of existing evidence, schema/response-directory rejection and actual metadata `modified=True/False` serialization. These address risks introduced by shared dispatch.
- Added PowerShell launcher integration: **15 scenarios passed** using fake COM and process inventory. Both actions, unique request directories, stale/malformed responses, metadata/sidecar mismatch, missing outputs/responses, refusal to overwrite existing evidence, rejected commands, error traceback, single-process guards and a real second-process mutex holder (an isolated test mutex name; the wrappers retain the shared production default) were checked. No Rhino COM object was created. These cover launcher association/concurrency/failure risks that the original downstream tests do not exercise.
- Original Blender background test: **passed**, exit 0, Blender **5.2.2 LTS**. It generated a fixture FBX with Blender and performed a real Blender FBX import, rebuild, independent verification, cleanup and normal audit. It also checked shared-data isolation, child compensation, UV controls, hidden geometry, intentional pivots, unsafe modifier/reentry/geometry/UV guards, outward/reversed/open normals, relocation and input tampering.
- Blender full fixture evidence: 3 meshes/occurrences, 1 Block, 4 Layer Empties, 1 packaging Collection; 29 prior objects preserved; maximum source BBox error about `5.97e-8 m`; cleanup world-vertex drift about `4.11e-8 m`; all scales one; 3 outward results. Standalone cleanup maximum normal-direction difference was about `0.00274°` and UV drift `1.79e-7`.
- Python AST syntax, PowerShell parser syntax and JavaScript syntax were checked. All **59** local Markdown file destinations and heading anchors passed; they are checked by [check_package.py](tests/check_package.py). The package contains exactly one SKILL.md and one agents/openai.yaml.

The first Python dispatcher test attempt exposed Python 3.12's removal of `imp`; the Rhino-only import was moved inside dispatch, and the corrected five tests passed. The retained Rhino timestamp implementation emits a Python 3.12 `utcnow()` deprecation warning during the mocked metadata test; it is retained for Rhino IronPython compatibility.

Test fixtures are generated at runtime and are excluded from the Skill package.

## Not established by these checks

Rhino, MoI and C4D were not started. The merged bridge has not been exercised with real Rhino COM/IronPython; real working-copy source geometry/selection/path/Modified preservation, Rhino 5 reopen behavior, MoI slider/batch/token handling and C4D protected mutation/Normal Tags/readback remain application regression gates. Blender MCP/live-user-scene interaction and screenshot/material-preview acceptance were not performed. The successful Blender test uses a synthetic Blender-exported FBX, not a MoI-generated FBX. Existing verified MoI-build notes are inherited evidence, not a new MoI validation. No same-FBX cross-target regression is claimed.
