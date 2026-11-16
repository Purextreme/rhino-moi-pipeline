"""Offline shared-dispatch regression: isolated requests and failure evidence, no Rhino."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('bridge', ROOT/'scripts/rhino-metadata/bridge_request.py')
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


class BridgeTests(unittest.TestCase):
    def request(self, directory, key):
        run = directory/key
        run.mkdir()
        data = dict(schema_version=1, action='metadata', request_id=key,
                    output_path=str(directory/(key+'.json')), response_path=str(run/'response.json'))
        path = run/'request.json'
        path.write_text(json.dumps(data), encoding='utf-8')
        return path, data

    def test_interleaved_requests_use_explicit_paths(self):
        with tempfile.TemporaryDirectory(dir=ROOT/'tests') as name:
            a, ra = self.request(Path(name), 'first')
            b, rb = self.request(Path(name), 'second')
            def execute(request):
                bridge.publish(request['output_path'], {'id': request['request_id']}, request['request_id'])
                return {'ok': True, 'request_id': request['request_id']}
            with patch.object(bridge, 'execute', side_effect=execute), contextlib.redirect_stdout(io.StringIO()):
                bridge.run(b)
                bridge.run(a)
            for request in (ra, rb):
                self.assertEqual(json.loads(Path(request['response_path']).read_text())['request_id'], request['request_id'])
                self.assertEqual(json.loads(Path(request['output_path']).read_text())['id'], request['request_id'])

    def test_failure_keeps_current_id_unicode_and_traceback_without_raising(self):
        with tempfile.TemporaryDirectory(dir=ROOT/'tests') as name:
            path, request = self.request(Path(name), 'failed')
            with patch.object(bridge, 'execute', side_effect=RuntimeError('失败证据')), contextlib.redirect_stdout(io.StringIO()):
                result = bridge.run(path)
            text = Path(request['response_path']).read_bytes()
            text.decode('ascii')
            self.assertFalse(result['ok'])
            self.assertEqual(result['request_id'], 'failed')
            self.assertEqual(result['message'], '失败证据')
            self.assertIn('RuntimeError', result['traceback'])
            self.assertEqual(json.loads(text), result)

    def test_existing_output_and_failed_serialization_preserve_evidence(self):
        with tempfile.TemporaryDirectory(dir=ROOT/'tests') as name:
            output = Path(name)/'evidence.json'
            output.write_text('original')
            with self.assertRaises(RuntimeError):
                bridge.publish(str(output), {'new': True}, 'a')
            self.assertEqual(output.read_text(), 'original')
            with self.assertRaises(TypeError):
                bridge.publish(str(output), {'bad': object()}, 'b')
            self.assertEqual(output.read_text(), 'original')
            self.assertFalse(Path(str(output)+'.b.tmp').exists())

    def test_wrong_response_directory_and_schema_rejected(self):
        with tempfile.TemporaryDirectory(dir=ROOT/'tests') as name:
            path, request = self.request(Path(name), 'bad')
            request['response_path'] = str(Path(name)/'other-response.json')
            path.write_text(json.dumps(request))
            with self.assertRaisesRegex(ValueError, 'this request directory'):
                bridge.read_request(path)
            request['schema_version'] = 2
            path.write_text(json.dumps(request))
            with self.assertRaisesRegex(ValueError, 'Unsupported'):
                bridge.read_request(path)

    def test_metadata_retains_modified_state(self):
        # Exercise the real serializer with empty Rhino tables and a minimal document.
        import sys
        from types import SimpleNamespace
        spec = importlib.util.spec_from_file_location('metadata', ROOT/'scripts/rhino-metadata/export_rhino_metadata.py')
        module = importlib.util.module_from_spec(spec)
        with patch.dict(sys.modules, {'Rhino': SimpleNamespace(), 'scriptcontext': SimpleNamespace()}):
            spec.loader.exec_module(module)
        for modified in (True, False):
            doc = SimpleNamespace(Name='unsaved', Path='', RuntimeSerialNumber=42, Modified=modified,
                                  ModelUnitSystem='Millimeters', ModelAbsoluteTolerance=0.01,
                                  InstanceDefinitions=[], Objects=[], Layers=[])
            data = module.build_metadata(doc, 'current')
            self.assertIs(data['document']['modified'], modified)
            self.assertEqual(data['automation']['request_id'], 'current')


if __name__ == '__main__':
    unittest.main()
