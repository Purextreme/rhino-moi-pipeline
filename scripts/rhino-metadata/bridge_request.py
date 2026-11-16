# -*- coding: utf-8 -*-
"""Per-request Rhino 7 IronPython dispatch; no fixed mailbox or user profile I/O."""
import io
import json
import os
import traceback


def read_request(path):
    with io.open(path, 'r', encoding='utf-8-sig') as stream:
        request = json.load(stream)
    for key in ('request_id', 'output_path', 'response_path', 'action'):
        if not request.get(key):
            raise ValueError('Request is missing required field: ' + key)
    if request.get('schema_version') != 1 or request['action'] not in ('metadata', 'working_copy'):
        raise ValueError('Unsupported bridge request')
    if request['response_path'] != os.path.join(os.path.dirname(os.path.abspath(path)), 'response.json'):
        raise ValueError('Response must belong to this request directory')
    return request


def publish(path, value, request_id):
    # Serialize before touching a file; ASCII is safe for Rhino 7 IronPython responses.
    text = json.dumps(value, ensure_ascii=True, indent=2)
    temporary = path + '.' + request_id + '.tmp'
    with io.open(temporary, 'w', encoding='ascii') as stream:
        stream.write(u'{0}'.format(text))
    if os.path.exists(path):
        raise RuntimeError('Refuse to replace existing output: ' + path)
    os.rename(temporary, path)


def execute(request):
    import imp  # Rhino 7 IronPython; imported only when dispatching inside Rhino.
    directory = os.path.dirname(__file__)
    if request['action'] == 'working_copy':
        module = imp.load_source('rhino_moi_working_copy', os.path.join(directory, 'prepare_working_copy.py'))
        return module.main(request)
    import scriptcontext as sc
    module = imp.load_source('rhino_moi_metadata', os.path.join(directory, 'export_rhino_metadata.py'))
    if os.path.exists(request['output_path']):
        raise RuntimeError('Metadata output already exists; inspect before retry')
    metadata = module.build_metadata(sc.doc, request['request_id'])
    publish(request['output_path'], metadata, request['request_id'])
    return {'schema_version': 1, 'request_id': request['request_id'], 'ok': True,
            'output_path': request['output_path'],
            'output_bytes': int(os.path.getsize(request['output_path'])),
            'document': metadata['document'], 'counts': metadata['counts'],
            'exported_utc': metadata['automation']['exported_utc']}


def run(request_path):
    request = None
    try:
        request = read_request(request_path)
        response = execute(request)
    except Exception as error:
        response = {'schema_version': 1, 'ok': False,
                    'request_id': request.get('request_id') if request else None,
                    'error_code': 'RHINO_EXPORT_FAILED', 'message': str(error),
                    'traceback': traceback.format_exc()}
    if request:
        try:
            publish(request['response_path'], response, request['request_id'])
        except Exception:
            # Missing/malformed response remains unknown completion to the caller.
            print(traceback.format_exc())
    print(json.dumps(response, ensure_ascii=True))
    # Do not raise into Rhino's modal IronPython error dialog after failure publication.
    return response
