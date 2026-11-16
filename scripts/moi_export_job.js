// The launcher prepends a JSON job object and runs this in a separate MoI process.
function writeState(stage, detail) {
    var stream = moi.filesystem.openFileStream(job.state, 'w');
    stream.writeLine(stage + (detail ? ': ' + detail : ''));
    stream.close();
}

try {
    writeState('started');
    var db = moi.geometryDatabase;
    if (db.getObjects().length !== 0) throw 'Expected an empty batch document';
    if (!moi.filesystem.fileExists(job.transport)) throw 'Missing transport file';
    db.open(job.transport, true);

    var objects = db.getObjects();
    var breps = objects.getBReps();
    if (objects.length !== job.tokens.length || breps.length !== job.tokens.length) {
        throw 'Expected ' + job.tokens.length + ' Breps; loaded ' + breps.length +
            ' Breps in ' + objects.length + ' objects';
    }
    var actual = [];
    for (var i = 0; i < breps.length; ++i) actual.push(String(breps.item(i).name));
    actual.sort();
    for (var index = 0; index < actual.length; ++index) {
        if (actual[index] !== job.tokens[index]) {
            throw 'Transport token mismatch: expected ' + job.tokens[index] + ', got ' + actual[index];
        }
    }
    db.selectAll();
    if (db.getSelectedObjects().length !== breps.length) throw 'Incomplete export selection';
    if (moi.filesystem.fileExists(job.output)) throw 'Temporary FBX already exists';
    writeState('exporting', String(breps.length));
    db.fileExport(job.output, job.options);
    if (!moi.filesystem.fileExists(job.output)) throw 'Export returned without an FBX';
    writeState('completed', String(breps.length));
} catch (error) {
    writeState('failed', String(error));
} finally {
    moi.exit(true);
}
