"""Exercise the opt-in Layer matcher without a Cinema 4D session."""

import importlib.util
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from uuid import UUID


TARGET = Path(__file__).resolve().parents[1] / "scripts/c4d/rebuild_layers_from_rhino.py"


def load_matcher():
    spec = importlib.util.spec_from_file_location("rebuild_layers", TARGET)
    module = importlib.util.module_from_spec(spec)
    # This C4D bridge script calls main() at import. The placeholder path
    # guard fires before it attempts to access the active C4D document.
    with patch.dict(sys.modules, {"c4d": SimpleNamespace(Tnormal=1, Ttexture=2)}):
        try:
            spec.loader.exec_module(module)
        except RuntimeError as exc:
            if str(exc) != "Set METADATA_PATH before running this script":
                raise
    module.exact_world_bbox = lambda obj: obj.bounds
    return module


class Polygon:
    def __init__(self, name, bounds):
        self.name = name
        self.bounds = bounds

    def GetName(self):
        return self.name

    def GetDown(self):
        return None

    def GetTags(self):
        return [SimpleNamespace(CheckType=lambda tag_type: tag_type == 1)]


class SourceIdMatchingTests(unittest.TestCase):
    def setUp(self):
        self.matcher = load_matcher()
        self.records = [
            self.record(1, (1, 3, 7), (3, 8, 18)),
            self.record(2, (1, 3, 7), (3, 8, 18)),
            self.record(3, (21, 15, 31), (25, 25, 47)),
        ]
        self.polygons = [self.polygon(item) for item in reversed(self.records)]

    def record(self, number, minimum, maximum):
        return {
            "id": str(UUID(int=number)),
            "type": "Brep",
            "layer": "Example",
            "bbox": {"min": dict(zip("xyz", minimum)), "max": dict(zip("xyz", maximum))},
        }

    def polygon(self, item):
        bounds = item["bbox"]
        return Polygon("RHINO_ID_" + UUID(item["id"]).hex, {
            "min": [-bounds["max"]["z"] + 100, bounds["min"]["x"] - 6, bounds["min"]["y"] + 11],
            "max": [-bounds["min"]["z"] + 100, bounds["max"]["x"] - 6, bounds["max"]["y"] + 11],
        })

    def test_opt_in_uses_identity_for_identical_bounding_boxes(self):
        with self.assertRaisesRegex(RuntimeError, "BBox matching is ambiguous"):
            self.matcher.match_geometry(self.records, self.polygons)
        self.matcher.USE_SOURCE_IDS = True
        assignment, evidence = self.matcher.match_geometry(self.records, self.polygons)
        self.assertEqual(assignment, [2, 1, 0])
        self.assertEqual(evidence["source_id_matches"], 3)
        self.assertEqual(evidence["translation"], [100, -6, 11])
        self.assertEqual(evidence["max_error"], 0.0)

    def test_default_matcher_still_accepts_distinct_bounding_boxes(self):
        self.polygons[0].name = self.polygons[2].name = "Imported geometry"
        assignment, evidence = self.matcher.match_geometry(
            [self.records[0], self.records[2]], [self.polygons[0], self.polygons[2]]
        )
        self.assertEqual(assignment, [1, 0])
        self.assertEqual(evidence["max_error"], 0.0)

    def test_rejects_incomplete_or_duplicate_import_tokens(self):
        self.matcher.USE_SOURCE_IDS = True
        self.polygons[0].name = "Unknown"
        with self.assertRaisesRegex(RuntimeError, "exactly match"):
            self.matcher.match_geometry(self.records, self.polygons)
        self.polygons[0].name = self.polygons[1].name
        with self.assertRaisesRegex(RuntimeError, "Duplicate polygon names"):
            self.matcher.match_geometry(self.records, self.polygons)

    def test_duplicate_metadata_uuid_is_rejected_across_formats(self):
        self.matcher.USE_SOURCE_IDS = True
        self.records[0]["id"] = UUID(self.records[1]["id"]).hex.upper()
        with self.assertRaisesRegex(RuntimeError, "Duplicate source IDs"):
            self.matcher.match_geometry(self.records, self.polygons)

    def test_correct_tokens_cannot_override_bad_geometry(self):
        self.matcher.USE_SOURCE_IDS = True
        self.polygons[0].bounds["max"][0] += 1.0
        with self.assertRaisesRegex(RuntimeError, "max error .* exceeds"):
            self.matcher.match_geometry(self.records, self.polygons)

    def test_nonfinite_coordinates_are_rejected(self):
        self.matcher.USE_SOURCE_IDS = True
        self.polygons[0].bounds["min"][0] = float("nan")
        with self.assertRaisesRegex(RuntimeError, "finite C4D bounding boxes"):
            self.matcher.match_geometry(self.records, self.polygons)


if __name__ == "__main__":
    unittest.main()
