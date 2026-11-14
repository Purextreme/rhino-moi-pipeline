"""Offline tests for Layer/Block mode selection; no C4D session is used."""
import ast
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest

TARGET = Path(sys.argv.pop(1)) if len(sys.argv) > 1 else Path(__file__).resolve().parents[1] / 'scripts/c4d/rebuild_layers_from_rhino.py'
tree = ast.parse(TARGET.read_text(encoding='utf-8'))
function = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == 'validate_scene')
namespace = {'c4d': SimpleNamespace(Opolygon=5100), 'ROOT_NAME': 'RHINO_METADATA_REBUILT', 'GEOMETRY_TYPES': ('Brep', 'Extrusion', 'Mesh', 'Surface', 'SubD')}
exec(compile(ast.Module(body=[function], type_ignores=[]), str(TARGET), 'exec'), namespace)
validate_scene = namespace['validate_scene']

class Polygon:
    def CheckType(self, type_id):
        return type_id == 5100

class Document:
    def __init__(self, objects=None):
        self.objects = [Polygon()] if objects is None else objects

    def SearchObject(self, name):
        return None

    def GetObjects(self):
        return self.objects

class ModeSelectionTests(unittest.TestCase):
    def metadata(self):
        return {'counts': {'instance_definitions': 1, 'top_level_instance_references': 0}, 'objects': [{'type': 'Brep'}]}

    def test_unused_definitions_allow_layer_mode(self):
        metadata = self.metadata()
        geo, polygons = validate_scene(Document(), metadata)
        self.assertEqual(geo, metadata['objects'])
        self.assertEqual(len(polygons), 1)

    def test_declared_live_instances_reject_layer_mode(self):
        metadata = self.metadata()
        metadata['counts']['top_level_instance_references'] = 1
        with self.assertRaisesRegex(RuntimeError, 'Block'):
            validate_scene(Document(), metadata)

    def test_live_record_rejected_even_with_stale_zero_count(self):
        metadata = self.metadata()
        metadata['counts']['instance_definitions'] = 0
        metadata['objects'].append({'type': 'InstanceReference'})
        with self.assertRaisesRegex(RuntimeError, 'Block'):
            validate_scene(Document(), metadata)

    def test_live_block_flag_rejected(self):
        metadata = self.metadata()
        metadata['counts'] = {}
        metadata['objects'][0]['block'] = {'is_instance_reference': True}
        with self.assertRaisesRegex(RuntimeError, 'Block'):
            validate_scene(Document(), metadata)

    def test_geometry_count_mismatch_still_rejected(self):
        metadata = self.metadata()
        metadata['counts']['instance_definitions'] = 0
        with self.assertRaisesRegex(RuntimeError, 'count mismatch'):
            validate_scene(Document(objects=[]), metadata)

    def test_non_polygon_import_still_rejected(self):
        metadata = self.metadata()
        metadata['counts']['instance_definitions'] = 0
        non_polygon = SimpleNamespace(CheckType=lambda type_id: False)
        with self.assertRaisesRegex(RuntimeError, 'polygon-only'):
            validate_scene(Document(objects=[non_polygon]), metadata)

if __name__ == '__main__':
    unittest.main()
