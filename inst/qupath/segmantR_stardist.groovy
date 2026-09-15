/*
 * segmantR QuPath template: StarDist nucleus detection
 * Template version 1.0.0 - reads run.json (schema segmantR-qupath-run-v1)
 *
 * Headless (QuPath command line):
 *   QuPath script --project=project.qpproj --image="<image name>" \
 *     --args=<path>/run.json segmantR_stardist.groovy
 *   Use --save only when run.json declares "save_policy": "project"; the
 *   script saves explicitly in that case and never otherwise.
 *
 * Interactive (Automate > Script editor):
 *   Put this file, run.json and its resources in <project>/segmantR/, open
 *   the image, then run the script. Without --args the script reads
 *   <project>/segmantR/run.json.
 *
 * What it does: validates run.json, checks the QuPath and extension versions,
 * the image size, pixel calibration, plane and channels, verifies the model
 * digest, runs StarDist with the declared parameters only, and writes the
 * declared outputs (GeoJSON, integer label TIFF, measurements, manifest,
 * integrity.json). It evaluates no code from run.json and resolves only
 * relative paths inside the run.json directory.
 */

import qupath.lib.io.GsonTools
import qupath.lib.objects.PathObjects
import qupath.lib.roi.ROIs
import qupath.lib.regions.ImagePlane
import qupath.lib.common.GeneralTools
import com.google.gson.GsonBuilder
import java.security.MessageDigest
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.awt.image.BufferedImage
import java.awt.RenderingHints
import java.awt.Color

def TEMPLATE_VERSION = '1.0.0'
def TASK = 'stardist'

// ---- helpers (closures so they can see script variables) -----------------
def fail = { String msg -> throw new IllegalStateException('segmantR: ' + msg) }
def hex = { byte[] b -> b.collect { String.format('%02x', it & 0xff) }.join('') }
def sha256File = { File f ->
    def md = MessageDigest.getInstance('SHA-256')
    f.withInputStream { is ->
        byte[] buf = new byte[65536]
        int n
        while ((n = is.read(buf)) > 0) md.update(buf, 0, n)
    }
    hex(md.digest())
}
def jsonString = { String s ->
    if (s == null) return 'null'
    def sb = new StringBuilder('"')
    s.codePoints().forEach { int cp ->
        switch (cp) {
            case 0x22: sb.append('\\"'); break
            case 0x5c: sb.append('\\\\'); break
            case 0x08: sb.append('\\b'); break
            case 0x0c: sb.append('\\f'); break
            case 0x0a: sb.append('\\n'); break
            case 0x0d: sb.append('\\r'); break
            case 0x09: sb.append('\\t'); break
            default:
                if (cp < 0x20) sb.append(String.format('\\u%04x', cp))
                else sb.appendCodePoint(cp)
        }
    }
    sb.append('"').toString()
}
def versionAtLeast = { String have, String need ->
    def h = (have ?: '0').tokenize('.-').take(3).collect { it.isInteger() ? it as int : 0 }
    def n = need.tokenize('.-').take(3).collect { it as int }
    while (h.size() < 3) h << 0
    for (int i = 0; i < 3; i++) {
        if (h[i] != n[i]) return h[i] > n[i]
    }
    true
}

// ---- locate and read run.json -------------------------------------------
File runFile
if (binding.hasVariable('args') && args != null && args.length > 0) {
    runFile = new File(args[0]).getCanonicalFile()
} else {
    def project = getProject()
    if (project == null) fail('open a project or pass run.json with --args')
    runFile = new File(buildFilePath(PROJECT_BASE_DIR, 'segmantR', 'run.json')).getCanonicalFile()
}
if (!runFile.isFile()) fail('run.json not found: ' + runFile.getName())
File runDir = runFile.getParentFile()
def resolve = { String rel ->
    if (rel == null || rel.isEmpty() || rel.startsWith('/') || rel.startsWith('~') ||
            rel.contains('\\') || rel ==~ /^[A-Za-z]:.*/ ||
            rel.split('/', -1).any { it == '..' || it == '.' || it.isEmpty() })
        fail('unsafe relative path in run.json: ' + rel)
    File f = new File(runDir, rel).getCanonicalFile()
    if (!f.getPath().startsWith(runDir.getPath() + File.separator))
        fail('path leaves the run directory: ' + rel)
    f
}
def run = GsonTools.getInstance().fromJson(runFile.getText('UTF-8'), Map)
if (run.schema != 'segmantR-qupath-run-v1') fail('unsupported run schema ' + run.schema)
if (!(run.schema_version as String).startsWith('1.')) fail('unsupported run schema version ' + run.schema_version)
if (run.task != TASK) fail('this template runs task ' + TASK + ', run.json declares ' + run.task)
if (!versionAtLeast(TEMPLATE_VERSION, run.template_version as String))
    fail('run.json needs template version ' + run.template_version)
def qupathVersion = GeneralTools.getVersion()
if (!versionAtLeast(qupathVersion, run.qupath.min_version as String))
    fail('QuPath ' + run.qupath.min_version + ' or newer is required (found ' + qupathVersion + ')')
def extVersion = null
try {
    extVersion = Class.forName('qupath.ext.stardist.StarDist2D').getPackage().getImplementationVersion()
} catch (Throwable e) {
    fail('the QuPath StarDist extension is not installed')
}
if (run.qupath.extension != null && extVersion != null &&
        !versionAtLeast(extVersion, run.qupath.extension.min_version as String))
    fail('StarDist extension ' + run.qupath.extension.min_version + ' or newer is required (found ' + extVersion + ')')

// ---- image binding -------------------------------------------------------
def imageData = getCurrentImageData()
if (imageData == null) fail('no image is open')
def server = imageData.getServer()
def b = run.image_binding
int W = server.getWidth()
int H = server.getHeight()
if (b.width != null && W != (b.width as int)) fail('image width ' + W + ' != ' + (b.width as int))
if (b.height != null && H != (b.height as int)) fail('image height ' + H + ' != ' + (b.height as int))
def entry = getProjectEntry()
String imageName = entry != null ? entry.getImageName() : server.getMetadata().getName()
if (b.image_name != null && imageName != b.image_name) fail('image name "' + imageName + '" != "' + b.image_name + '"')
def cal = server.getPixelCalibration()
if (b.require_calibration && !cal.hasPixelSizeMicrons()) fail('the image has no pixel calibration in micrometres')
if (b.pixel_size_um != null) {
    if (!cal.hasPixelSizeMicrons()) fail('run.json declares a pixel size but the image is uncalibrated')
    double tol = (b.pixel_size_um.tolerance ?: 1e-6) as double
    double px = cal.getPixelWidthMicrons(), py = cal.getPixelHeightMicrons()
    if (Math.abs(px - (b.pixel_size_um.x as double)) > tol * Math.max(1d, px) ||
            Math.abs(py - (b.pixel_size_um.y as double)) > tol * Math.max(1d, py))
        fail('pixel size ' + px + ' x ' + py + ' um does not match run.json')
}
int z = b.plane.z as int
int t = b.plane.t as int
if ((b.plane.level as int) != 0 || (b.plane.series as int) != 0) fail('only level 0 of the opened series is supported')
if (z >= server.nZSlices() || t >= server.nTimepoints()) fail('plane z=' + z + ' t=' + t + ' is outside the image')
def channelNames = server.getMetadata().getChannels().collect { it.getName() }
if (b.channels != null && b.channels as List != channelNames)
    fail('channel names ' + channelNames + ' != ' + b.channels)

// ---- model ---------------------------------------------------------------
def sd = run.stardist
if (sd == null) fail('run.json has no stardist block')
File modelFile = resolve(sd.model.path as String)
if (!modelFile.exists()) fail('model not found: ' + sd.model.path)
def inventoryDigest = { File root, List<File> files ->
    def rows = files.collect { f ->
        String rel = root.isDirectory() ? root.toPath().relativize(f.toPath()).toString().replace(File.separator, '/') : f.getName()
        [rel, f.length(), sha256File(f)]
    }.sort { a, c -> a[0] <=> c[0] }
    String json = '{"files":[' + rows.collect { r ->
        '{"path":' + jsonString(r[0]) + ',"sha256":"' + r[2] + '","size_bytes":' + r[1] + '}'
    }.join(',') + '],"format_version":"1.0"}'
    'sha256:' + hex(MessageDigest.getInstance('SHA-256').digest(json.getBytes('UTF-8')))
}
def modelFiles = []
if (modelFile.isDirectory()) {
    modelFile.eachFileRecurse(groovy.io.FileType.FILES) { if (!it.getName().startsWith('.')) modelFiles << it }
} else {
    modelFiles << modelFile
}
String modelDigest = inventoryDigest(modelFile, modelFiles)
if (modelDigest != sd.model.digest) fail('model digest ' + modelDigest + ' does not match run.json')

// ---- regions -------------------------------------------------------------
def hierarchy = imageData.getHierarchy()
List parents
switch (run.region_policy) {
    case 'whole_image':
        def roi = ROIs.createRectangleROI(0, 0, W, H, ImagePlane.getPlane(z, t))
        def region = PathObjects.createAnnotationObject(roi)
        region.setName('segmantR region ' + run.run_id)
        hierarchy.addObject(region)
        parents = [region]
        break
    case 'selected_annotations':
        parents = hierarchy.getSelectionModel().getSelectedObjects().findAll { it.isAnnotation() }
        break
    case 'all_annotations':
        parents = hierarchy.getAnnotationObjects().collect { it }
        break
    default:
        fail('unknown region_policy ' + run.region_policy)
}
if (parents.isEmpty()) fail('no region to process (region_policy ' + run.region_policy + ')')

println 'segmantR plan: StarDist ' + (extVersion ?: '?') + ' on "' + imageName + '" (' + W + ' x ' + H +
        ' px, z=' + z + ', t=' + t + '), ' + parents.size() + ' region(s), model ' + sd.model.path +
        ', threshold ' + sd.threshold + ', save_policy ' + run.save_policy + ', outputs ' + run.outputs.directory
if (!run.unsupported.isEmpty()) println 'segmantR: unsupported/approximated parameters: ' + run.unsupported.collect { it.parameter + ' (' + it.status + ')' }.join(', ')

// ---- StarDist ------------------------------------------------------------
def StarDist2D = Class.forName('qupath.ext.stardist.StarDist2D')
def builder = StarDist2D.builder(modelFile.getAbsolutePath())
builder.threshold(sd.threshold as double)
def chans = sd.channels as List
if (chans.every { it instanceof Number }) {
    builder.channels(chans.collect { it as int } as int[])
} else {
    builder.channels(chans.collect { it as String } as String[])
}
if (sd.normalization.scope == 'tile') {
    builder.normalizePercentiles(sd.normalization.low as double, sd.normalization.high as double)
} else {
    def nb = StarDist2D.imageNormalizationBuilder().percentiles(sd.normalization.low as double, sd.normalization.high as double)
    if (sd.normalization.max_dimension != null) nb = nb.maxDimension(sd.normalization.max_dimension as int)
    builder.preprocessGlobal(nb.build())
}
if (sd.pixel_size_um != null) builder.pixelSize(sd.pixel_size_um as double)
if (sd.tile_size != null) builder.tileSize(sd.tile_size as int)
if (sd.include_probability) builder.includeProbability(true)
if (sd.cell_expansion_um != null) builder.cellExpansion(sd.cell_expansion_um as double)
if (sd.cell_constrain_scale != null) builder.cellConstrainScale(sd.cell_constrain_scale as double)
if (sd.create_annotations) builder.createAnnotations()
if (sd.classification != null) builder.classify(sd.classification as String)
if (sd.measure_shape) builder.measureShape()
if (sd.measure_intensity) builder.measureIntensity()
builder.nThreads(sd.n_threads as int)
def detector = builder.build()
try {
    detector.detectObjects(imageData, parents)
} finally {
    detector.close()
}

def objectTypes = (run.outputs.object_types ?: ['detection']) as List
def results = parents.collectMany { p ->
    p.getChildObjects().findAll { o ->
        (o.isCell() && objectTypes.contains('cell')) ||
                (o.isDetection() && !o.isCell() && objectTypes.contains('detection')) ||
                (o.isAnnotation() && objectTypes.contains('annotation'))
    }
}.sort { it.getID().toString() }
println 'segmantR: ' + results.size() + ' object(s) detected'
if (results.isEmpty())
    println 'segmantR: WARNING no objects were detected; StarDist logs internal errors without failing - check the log above'

// ---- outputs ---------------------------------------------------------------
File outDir = resolve(run.outputs.directory as String)
outDir.mkdirs()
def assets = []
def addAsset = { String role, String media, File f ->
    assets << [role: role, path: f.getName(), media_type: media, size_bytes: f.length(), sha256: sha256File(f)]
}
if (run.outputs.geojson != null) {
    File gj = new File(outDir, run.outputs.geojson as String)
    exportObjectsToGeoJson(results, gj.getPath(), 'FEATURE_COLLECTION')
    addAsset('qupath_geojson', 'application/geo+json', gj)
}
String contentDigest = null
if (run.outputs.mask_tiff != null) {
    if ((long) W * H > 134217728L) fail('label mask export is limited to 134217728 pixels; process tiles instead')
    def img = new BufferedImage(W, H, BufferedImage.TYPE_INT_RGB)
    def g = img.createGraphics()
    g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_OFF)
    // Pure stroke control: sample exactly at pixel centres (no half-pixel normalisation)
    g.setRenderingHint(RenderingHints.KEY_STROKE_CONTROL, RenderingHints.VALUE_STROKE_PURE)
    results.eachWithIndex { o, i ->
        g.setColor(new Color(i + 1))
        g.fill(o.getROI().getShape())
    }
    g.dispose()
    int[] vals = new int[W * H]
    for (int yy = 0; yy < H; yy++) for (int xx = 0; xx < W; xx++) vals[yy * W + xx] = img.getRGB(xx, yy) & 0xFFFFFF
    int nData = W * H * 4
    def bb = ByteBuffer.allocate(8 + nData + 2 + 10 * 12 + 4).order(ByteOrder.LITTLE_ENDIAN)
    bb.put((byte) 0x49).put((byte) 0x49).putShort((short) 42).putInt(8 + nData)
    for (int v : vals) bb.putInt(v)
    bb.putShort((short) 10)
    def tag = { int id, int type, int value ->
        bb.putShort((short) id).putShort((short) type).putInt(1)
        if (type == 3) { bb.putShort((short) value).putShort((short) 0) } else { bb.putInt(value) }
    }
    tag(256, 4, W); tag(257, 4, H); tag(258, 3, 32); tag(259, 3, 1); tag(262, 3, 1)
    tag(273, 4, 8); tag(277, 3, 1); tag(278, 4, H); tag(279, 4, nData); tag(339, 3, 1)
    bb.putInt(0)
    File mf = new File(outDir, run.outputs.mask_tiff as String)
    mf.bytes = bb.array()
    def md = MessageDigest.getInstance('SHA-256')
    md.update(ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN).putInt(H).putInt(W).array())
    md.update(bb.array(), 8, nData)
    contentDigest = 'sha256:' + hex(md.digest())
    addAsset('mask_tiff', 'image/tiff', mf)
}
def legend = []
results.eachWithIndex { o, i ->
    legend << [label: i + 1, object_id: o.getID().toString(),
               'class': o.getPathClass() == null ? null : o.getPathClass().toString(),
               name: o.getName()]
}
String revision = null
if (contentDigest != null) {
    String legendJson = '[' + legend.collect { e ->
        '{"class":' + jsonString(e['class'] as String) + ',"label":' + e.label + ',"object_id":' + jsonString(e.object_id as String) + '}'
    }.join(',') + ']'
    String revJson = '{"labels":"' + contentDigest + '","legend":' + legendJson + ',"mask_type":"instance"}'
    revision = 'sha256:' + hex(MessageDigest.getInstance('SHA-256').digest(revJson.getBytes('UTF-8')))
}
def q = { String s -> s == null ? '' : '"' + s.replace('"', '""') + '"' }
def measurementNames = new TreeSet()
int nRows = 0
if (run.outputs.measurements != null) {
    File mc = new File(outDir, run.outputs.measurements as String)
    mc.withWriter('UTF-8') { w ->
        w.write('image_id,object_id,label,name,namespace,value,value_state,unit,provider_id\n')
        results.eachWithIndex { o, i ->
            o.getMeasurements().each { k, v ->
                double d = v == null ? Double.NaN : (v as double)
                String state = v == null ? 'missing' : Double.isNaN(d) ? 'nan' : d == Double.POSITIVE_INFINITY ? 'pos_inf' : d == Double.NEGATIVE_INFINITY ? 'neg_inf' : 'finite'
                String val = state == 'finite' ? Double.toString(d) : ''
                w.write([q(b.image_id as String ?: imageName), q(o.getID().toString()), (i + 1) as String, q(k as String),
                         q('stored'), val, q(state), q('unknown'), q('qupath')].join(',') + '\n')
                measurementNames << (k as String)
                nRows++
            }
        }
    }
    addAsset('measurements_csv', 'text/csv', mc)
}
if (run.outputs.native_measurements != null) {
    File nt = new File(outDir, run.outputs.native_measurements as String)
    saveDetectionMeasurements(nt.getPath())
    addAsset('other', 'text/tab-separated-values', nt)
}
def pixelSize = cal.hasPixelSizeMicrons() ? [x: cal.getPixelWidthMicrons(), y: cal.getPixelHeightMicrons(), unit: 'um'] : [x: null, y: null, unit: 'um']
def plane = [level: 0, series: 0, c: null, z: z, t: t]
def origin = [x: 0, y: 0, downsample: 1]
def dtypes = [UINT8: 'uint8', UINT16: 'uint16', UINT32: 'uint32', INT32: 'int32', FLOAT32: 'float32', FLOAT64: 'float64']
String imageId = (b.image_id ?: imageName) as String
def manifest = [
    schema: 'segmantR-interchange-v1', schema_version: '1.0.0', kind: 'qupath-export',
    id: run.run_id, created: java.time.Instant.now().truncatedTo(java.time.temporal.ChronoUnit.SECONDS).toString(),
    producer: [name: 'segmantR-qupath-template', version: TEMPLATE_VERSION, api_version: '1.0.0', source_revision: null, dirty: 'unknown'],
    coordinate_convention: [origin: 'top_left', x_axis: 'right', y_axis: 'down', units: 'px', pixel_centre: 'half_integer', array_order: 'y,x,channel', plane_index_base: 0],
    image: [id: imageId, source_name: imageName.replaceAll('[/\\\\]', '_'), shape_yx: [H, W], n_channels: channelNames.size(),
            array_order: 'y,x,channel', dtype: dtypes.get(server.getPixelType().toString(), 'float32'), channels: channelNames, bands: null,
            plane: plane, origin: origin, pixel_size: pixelSize, value_semantics: 'unknown', value_range: null,
            content_digest: null, source_digest: null, transform_digest: null, calibration_digest: null, read_accounting: null],
    mask: [id: 'qupath-' + run.run_id, image_id: imageId, mask_type: 'instance', dtype: 'uint32', background: 0, shape_yx: [H, W],
           label_count: results.size(), max_label: results.size(), plane: plane, origin: origin, connectivity: null,
           content_digest: contentDigest, revision: revision,
           review: [status: 'staged', revision: null, parent_revision: null, reviewed_at: null, reviewer: null],
           legend: legend, classes: legend.collect { it['class'] }.findAll { it != null }.unique().sort().collect { [name: it, color: null] },
           model_digest: modelDigest, transform_digest: null],
    protocol: run.protocol,
    measurements: [n_rows: nRows, namespace: 'stored', columns: ['image_id', 'object_id', 'label', 'name', 'namespace', 'value', 'value_state', 'unit', 'provider_id'], names: measurementNames as List],
    assets: assets,
    conversions: [
        [from: 'qupath-roi', to: 'qupath-geojson', fidelity: 'exact', notes: 'QuPath GeoJSON export of the detected ROIs', count: results.size()],
        [from: 'qupath-roi', to: 'mask', fidelity: 'approximated', notes: 'Java2D pixel-centre fill of polygon ROIs with float vertices; later objects overwrite earlier ones', count: results.size()]
    ],
    integrity_file: 'integrity.json',
    extensions: [qupath: [version: qupathVersion, stardist_extension_version: extVersion, template_version: TEMPLATE_VERSION, task: TASK,
                          run_id: run.run_id, region_policy: run.region_policy, save_policy: run.save_policy, n_regions: parents.size()]]
]
if (manifest.protocol == null) manifest.remove('protocol')
File manifestFile = new File(outDir, 'manifest.json')
manifestFile.setText(new GsonBuilder().serializeNulls().setPrettyPrinting().disableHtmlEscaping().create().toJson(manifest), 'UTF-8')
def inventory = []
outDir.eachFileRecurse(groovy.io.FileType.FILES) { f ->
    if (f.getName() != 'integrity.json') inventory << f
}
def rows = inventory.collect { f -> [outDir.toPath().relativize(f.toPath()).toString().replace(File.separator, '/'), f.length(), sha256File(f)] }
        .sort { a, c -> a[0] <=> c[0] }
new File(outDir, 'integrity.json').setText('{"files":[' + rows.collect { r ->
    '{"path":' + jsonString(r[0]) + ',"sha256":"' + r[2] + '","size_bytes":' + r[1] + '}'
}.join(',') + '],"format_version":"1.0"}', 'UTF-8')

// ---- save policy -----------------------------------------------------------
if (run.save_policy == 'project') {
    if (entry == null) fail('save_policy "project" needs a project')
    entry.saveImageData(imageData)
    println 'segmantR: image data saved to the project'
} else {
    println 'segmantR: save_policy "none" - project data were not saved'
}
println 'segmantR: outputs written to ' + run.outputs.directory
