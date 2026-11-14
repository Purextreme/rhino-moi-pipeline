"""Stamp a scope-validated Rhino 5 transport copy in Rhino 7 IronPython."""

import codecs
import json
import os
import tempfile
from uuid import UUID

import Rhino
from System.IO import File


# Match the supported metadata types in the equal-count C4D Layer rebuild.
GEOMETRY_TYPES = ("Brep", "Extrusion", "Mesh", "Surface", "SubD")


def top_level_objects(model):
    objects = {}
    for obj in model.Objects:
        if obj.Attributes.IsInstanceDefinitionObject:
            continue
        source_id = UUID(str(obj.Attributes.ObjectId))
        if source_id in objects:
            raise RuntimeError("Duplicate top-level object IDs in the transport copy")
        objects[source_id] = obj
    return objects


def prepare_source_id_copy(metadata_path, input_path, output_path):
    """Write a distinct, verified Rhino 5 file from the current snapshot's copy."""
    with codecs.open(metadata_path, "r", "utf-8") as stream:
        metadata = json.load(stream)
    records = metadata["objects"]
    if metadata.get("counts", {}).get("top_level_instance_references") or any(
        item.get("type") == "InstanceReference"
        or (item.get("block") or {}).get("is_instance_reference") for item in records
    ):
        raise RuntimeError("Source-ID transport requires flat Layer metadata")

    source = {UUID(item["id"]): item for item in records}
    if len(source) != len(records) or UUID(int=0) in source:
        raise RuntimeError("Expected unique, nonzero Rhino object IDs in the metadata")
    names = {key: "RHINO_ID_" + key.hex for key, item in source.items()
             if item.get("type") in GEOMETRY_TYPES}
    if not names:
        raise RuntimeError("No supported Rhino geometry in the metadata")

    output_path = os.path.abspath(output_path)
    if os.path.exists(output_path):
        raise RuntimeError("Source-ID transport output already exists")
    model = Rhino.FileIO.File3dm.Read(input_path)
    if model is None:
        raise RuntimeError("Could not read the verified Rhino transport copy")
    try:
        top_level = top_level_objects(model)
        if set(top_level) != set(source):
            raise RuntimeError("Transport top-level IDs must match the Rhino metadata before stamping")
        if any(isinstance(obj.Geometry, Rhino.Geometry.InstanceReferenceGeometry)
               for obj in top_level.values()):
            raise RuntimeError("Source-ID transport requires a copy without live Block instances")
        for key, name in names.items():
            top_level[key].Attributes.Name = name

        staging = tempfile.mkdtemp(prefix="rhino-id-", dir=os.path.dirname(output_path))
        temporary = os.path.join(staging, "transport.3dm")
        try:
            if not model.Write(temporary, 5):
                raise RuntimeError("Could not write the Rhino 5 source-ID transport copy")
            verified = Rhino.FileIO.File3dm.Read(temporary)
            if verified is None:
                raise RuntimeError("Could not reopen the Rhino 5 source-ID transport copy")
            try:
                reopened = top_level_objects(verified)
                if set(reopened) != set(source) or any(
                    reopened[key].Attributes.Name != name for key, name in names.items()
                ):
                    raise RuntimeError("Source-ID transport copy did not retain the expected IDs and names")
            finally:
                verified.Dispose()
            File.Move(temporary, output_path)
        finally:
            if os.path.isfile(temporary):
                os.remove(temporary)
            os.rmdir(staging)
    finally:
        model.Dispose()

    return {"output_path": output_path, "tagged_objects": len(names),
            "request_id": metadata.get("automation", {}).get("request_id")}
