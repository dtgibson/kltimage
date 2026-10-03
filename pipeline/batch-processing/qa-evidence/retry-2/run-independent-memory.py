import os,subprocess
from pathlib import Path
p=Path("/tmp/klt-batch-retry-2-release/Build/Products/ReleaseTests")
x="/Applications/Xcode.app/Contents/Developer"
app=p/"KLT Image.app/Contents/MacOS/KLT Image"
env=os.environ|{"DEVELOPER_DIR":x,"DYLD_FRAMEWORK_PATH":str(p)+":"+x+"/Platforms/MacOSX.platform/Developer/Library/Frameworks","DYLD_LIBRARY_PATH":x+"/Platforms/MacOSX.platform/Developer/usr/lib","DYLD_INSERT_LIBRARIES":x+"/Platforms/MacOSX.platform/Developer/usr/lib/libXCTestBundleInject.dylib","XCInjectBundle":str(p/"KLT Image.app/Contents/PlugIns/KLTImageTests.xctest"),"XCInjectBundleInto":str(app)}
raise SystemExit(subprocess.run([str(app),"-XCTest","KLTImageTests.BatchProcessingTests/testQAFullResolutionShortAndHundredItemMemory"],env=env).returncode)
