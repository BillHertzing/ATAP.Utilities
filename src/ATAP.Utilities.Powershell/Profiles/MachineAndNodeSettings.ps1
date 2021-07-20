$global:MachineAndNodeSettings = @{
  # Machine Settings
utat01 = @{ DropBoxBaseDir = 'C:/Dropbox/'}
ncat016 = @{ DropBoxBaseDir = 'C:/Dropbox/'}
'ncat-ltb1' = @{ DropBoxBaseDir = 'D:/Dropbox/'}
 # Jenkins Node Settings
 WindowsDocumentationBuildJenkinsNode = @{
  PlantUmlClassDiagramGeneratorPath = 'C:\Users\whertzing\.dotnet\tools\puml-gen.exe'
  javaPath = 'C:\Program Files\AdoptOpenJDK\jre-16.0.1.9-hotspot\bin\java.exe'
  plantUMLJarPath = 'C:/ProgramData/chocolatey/lib/plantuml/tools/plantuml.jar'
  docfxPath = 'C:\ProgramData\chocolatey\bin\docfx.exe'
 }
 WindowsCodeBuildJenkinsNode = @{
  dotnetPath = 'C:\Program Files\dotnet\dotnet.exe'
 }
}
