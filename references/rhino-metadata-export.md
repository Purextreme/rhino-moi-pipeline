# Bundled Rhino metadata export

Use this component to export object, Layer, Block, transform, bounding-box, color, and material metadata from the active document in one running Rhino 7 instance. It is read-only with respect to the active Rhino document and requires no Rhino plug-in or manual ScriptEditor step.

## Run the exporter

1. Require Windows, Rhino 7, and exactly one running `Rhino.exe` process.
   - If none are running, stop and ask the user to open Rhino and the intended document.
   - If more than one is running, stop without connecting and ask the user to leave only the intended instance open.
   - Never close Rhino instances automatically.
2. Choose an absolute writable output path outside the Skill folder. Keep runtime metadata out of version control unless the user explicitly requests a fixture.
3. Resolve the directory containing this Skill's `SKILL.md`, then run its wrapper by absolute path:

```powershell
& '<skill-root>\scripts\rhino-metadata\invoke_export.ps1' -OutputPath 'C:\absolute\path\rhino_metadata.json'
```

4. Treat a nonzero exit code or a JSON response with `ok: false` as failure.
5. Before consuming metadata, verify the returned `request_id`, `output_path`, document path, and object counts. Require the metadata `automation.request_id` to match the current response.

Both wrappers dot-source `scripts/rhino-metadata/bridge.ps1`. Each call creates a fresh UUID and `.rhino-moi-bridge/<request-id>/` beside the chosen output, containing `request.json`, `run.py` and `response.json`. There is no global profile mailbox. The generated ASCII runner passes its exact request path to `bridge_request.py`; it never looks up a shared “latest request”. Paths are UTF-8/base64 data in the runner.

A named session mutex `Local\CodexRhinoMoiPipelineRhino7` covers both actions from process preflight through COM completion and validation. A concurrent call fails with `BRIDGE_BUSY` before COM instead of queuing or overwriting another request. An abandoned mutex also stops the call for inspection. Output directories must exist and output files must be fresh; existing outputs are evidence requiring inspection, never automatically replaced. The single-process check remains mandatory.

Request schema 1 has `action` (`metadata` for either target, or `working_copy` for the Blender occurrence branch), `request_id`, `output_path`, `response_path` and `created_utc`; working copies also carry `metadata_path`, `metadata_request_id` and `occurrences_path`. Metadata schema remains 2, with `document.modified` retained for both targets. Working-copy schema remains 2 with the original occurrence behavior.

Success requires matching response ID and output path plus nonempty artifacts. Metadata must also contain the current `automation.request_id`; a Blender sidecar must match its baseline metadata request ID and transport path. Both wrappers return structured `ok`, `request_id`, and on failure `error_code`, `message`, `traceback` plus available output/request/response paths. Original success fields (document/counts or occurrence counts/source_unchanged) are retained. A published Rhino failure is not re-raised into a modal IronPython dialog. Failure publication is serialized before opening a temporary ASCII file; successful outputs are published before the response.

`TimeoutSeconds` bounds response polling **after** synchronous `RunScript` returns; it cannot interrupt a blocked COM call. Inspect Rhino command history/dialogs, the request directory and outputs before recovery. A missing/malformed response or caller termination means unknown completion. Preserve evidence and do not retry while the original call is unresolved. In particular, do not kill a caller and infer that COM had no effect. The mutex protects these launchers, not independent manual Rhino scripts or other automation.

## Output contract

The exporter keeps schema version 2 for the reconstruction scripts. It includes:

- document identity/path/runtime serial number/modified state, units, tolerance, coordinate-system conventions, and automation request data;
- Layer table and full Layer paths;
- top-level objects and Block/Instance definitions;
- definition members, nested instances, transforms, and bounding boxes;
- object names, types, colors, materials, groups, visibility, locking, and user strings.

## Guardrails and recovery

- Do not modify, save, close, or change selection in the Rhino document.
- Do not reuse an output solely because it exists; accept only the current matching request ID.
- Do not bypass the single-instance check.
- Treat COM failure or timeout as unknown completion. Inspect the response and output request ID before retrying.
- If a nonzero metadata file exists but the response is missing or malformed, verify its request ID and the unchanged active document before deciding whether recovery is safe.

## Supplemental IronPython probes

When the bundled metadata is insufficient and a read-only Rhino 7 probe is needed:

- Save supplemental scripts as UTF-8 with `# -*- coding: utf-8 -*-` on the first line when they contain non-ASCII text. Rhino 7 uses IronPython 2.7: use Unicode path literals (`u"..."`) or ASCII `\uXXXX` escapes, and avoid Python 3-only syntax. A missing encoding declaration raises `SyntaxError: Non-ASCII character` before the script's `try/except` can run; validate source encoding and syntax before submitting through COM.
- Convert CLR scalar values to the intended Python JSON types explicitly. For example, use `int(doc.RuntimeSerialNumber)`; a CLR number can print like an integer while IronPython's JSON encoder rejects it as `is not JSON serializable`. Preserve numeric fields as numbers rather than using a blanket string fallback. The bundled exporter already converts this field.
- For file-object identity use `File3dmObject.Attributes.ObjectId`; document-object `Id` and attribute-object properties are different APIs. See [shared transport checks](rhino-moi-common.md#rhino-5-transport-checks) for ID-set validation and transport-scope recovery.
- For a small probe response, call `json.dumps` before opening the destination for writing. A serialization failure must not truncate an existing response or leave partial JSON that looks like a result. Keep the bundled exporter's temporary-file publication strategy for full metadata.
- Catch probe exceptions and return an `ok: false` response with the current request ID and traceback. When that failure response has been written successfully, do not re-raise into Rhino's interactive error dialog: it can hold a synchronous COM call until someone dismisses it. The caller must check the response, not just whether `RunScript` returned. If no valid response can be written, treat completion as unknown and inspect before retrying.

If a synchronous COM call is waiting on a Rhino error dialog, inspect and dismiss that specific dialog, let the original call finish, and inspect its output before submitting a corrected probe. Do not queue another `RunScript` while the first call is still unresolved. Serialization or encoding failures in a status probe are not evidence that geometry export failed.

These rules apply to supplemental probes; reuse the bundled exporter for the normal metadata snapshot.
