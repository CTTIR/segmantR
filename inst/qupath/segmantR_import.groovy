/*
 * segmantR QuPath template: import segmantR objects
 * Template version 1.0.0 - reads run.json (schema segmantR-qupath-run-v1)
 *
 * Headless (QuPath command line):
 *   QuPath script --project=project.qpproj --image="<image name>" \
 *     --args=<path>/run.json segmantR_import.groovy
 *   Use --save only when run.json declares "save_policy": "project".
 *
 * Interactive (Automate > Script editor):
 *   Put this file, run.json and the bundle in <project>/segmantR/, open the
 *   image and run the script. Without --args it reads
 *   <project>/segmantR/run.json.
 *
 * What it does: validates run.json, checks QuPath version, image size,
 * pixel calibration, plane and channels, verifies the SHA-256 of the
 * segmantR GeoJSON declared in run.json and of the manifest, refuses to
 * import object ids that already exist in the image, imports the objects
 * with their ids and classes, and saves only with save_policy "project".
 * It evaluates no code from run.json.
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
def TASK = 'import'

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

// ---- verify and read the segmantR objects -----------------------------------
def spec = run['import']
if (spec == null) fail('run.json has no import block')
File manifestIn = resolve(spec.manifest as String)
File geojsonIn = resolve(spec.geojson as String)
if (!geojsonIn.isFile()) fail('GeoJSON not found: ' + spec.geojson)
if (sha256File(geojsonIn) != spec.geojson_sha256) fail('GeoJSON SHA-256 does not match run.json')
def manifestDoc = GsonTools.getInstance().fromJson(manifestIn.getText('UTF-8'), Map)
if (manifestDoc.schema != 'segmantR-interchange-v1' || !(manifestDoc.schema_version as String).startsWith('1.'))
    fail('unsupported segmantR manifest ' + manifestDoc.schema + ' ' + manifestDoc.schema_version)
def asset = manifestDoc.assets.find { it.role == 'geojson' }
if (asset == null || asset.sha256 != spec.geojson_sha256) fail('manifest does not list this GeoJSON')
def maskDesc = manifestDoc.mask
if (maskDesc != null) {
    def shape = maskDesc.shape_yx.collect { it as int }
    if (shape[0] != H || shape[1] != W) fail('segmantR mask ' + shape[0] + ' x ' + shape[1] + ' does not match the image ' + H + ' x ' + W)
    if ((maskDesc.plane.z as int) != z || (maskDesc.plane.t as int) != t) fail('segmantR mask plane does not match run.json')
}
def imported = qupath.lib.io.PathIO.readObjects(geojsonIn.toPath())
def hierarchy = imageData.getHierarchy()
def existing = hierarchy.getAllObjects(true).collect { it.getID().toString() } as Set
def ids = imported.collect { it.getID().toString() }
if (ids.size() != (ids as Set).size()) fail('duplicate object ids in the GeoJSON')
def clash = ids.findAll { existing.contains(it) }
if (!clash.isEmpty()) fail(clash.size() + ' object id(s) already exist in the image (already imported?)')
imported.each { o ->
    def roi = o.getROI()
    if (roi == null) fail('object without ROI')
    if (roi.getZ() != z || roi.getT() != t) fail('object ' + o.getID() + ' lies on another plane')
    def bounds = roi.getBoundsX() < 0 || roi.getBoundsY() < 0 || roi.getBoundsX() + roi.getBoundsWidth() > W || roi.getBoundsY() + roi.getBoundsHeight() > H
    if (bounds) fail('object ' + o.getID() + ' lies outside the image')
}
println 'segmantR plan: import ' + imported.size() + ' object(s) into "' + imageName + '" (z=' + z + ', t=' + t + '), save_policy ' + run.save_policy
hierarchy.addObjects(imported)
File outDir = resolve(run.outputs.directory as String)
outDir.mkdirs()
def report = [schema: 'segmantR-qupath-import-report-v1', run_id: run.run_id, qupath_version: qupathVersion,
              template_version: TEMPLATE_VERSION, image_name: imageName, imported: imported.size(),
              object_ids_sha256: hex(MessageDigest.getInstance('SHA-256').digest(ids.sort().join('\n').getBytes('UTF-8'))),
              geojson_sha256: spec.geojson_sha256, save_policy: run.save_policy]
new File(outDir, 'import_report.json').setText(new GsonBuilder().serializeNulls().setPrettyPrinting().create().toJson(report), 'UTF-8')
def parents = []
// ---- save policy -----------------------------------------------------------
if (run.save_policy == 'project') {
    if (entry == null) fail('save_policy "project" needs a project')
    entry.saveImageData(imageData)
    println 'segmantR: image data saved to the project'
} else {
    println 'segmantR: save_policy "none" - project data were not saved'
}
println 'segmantR: import report written to ' + run.outputs.directory
