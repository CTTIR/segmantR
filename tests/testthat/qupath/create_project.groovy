/*
 * Evidence helper (not shipped): create a fresh QuPath project with one image.
 * QuPath script --args=<project dir> --args=<image file> create_project.groovy
 */
import qupath.lib.projects.Projects
import qupath.lib.images.servers.ImageServerProvider
import qupath.lib.images.ImageData
import java.awt.image.BufferedImage

def projDir = new File(args[0]).getCanonicalFile()
def imageFile = new File(args[1]).getCanonicalFile()
if (projDir.exists() && projDir.list().length > 0) throw new IllegalStateException('project directory is not empty')
projDir.mkdirs()
def project = Projects.createProject(projDir, BufferedImage.class)
def support = ImageServerProvider.getPreferredUriImageSupport(BufferedImage.class, imageFile.toURI().toString())
def builder = support.getBuilders().get(0)
def entry = project.addImage(builder)
def server = builder.build()
entry.setImageName(imageFile.getName())
entry.saveImageData(new ImageData(server))
project.syncChanges()
println 'created project with image ' + imageFile.getName() + ' (' + server.getWidth() + 'x' + server.getHeight() + ', px ' + server.getPixelCalibration().getAveragedPixelSizeMicrons() + ' um)'
