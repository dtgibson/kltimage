import SwiftUI

@main struct KLTImageIOSApp: App {
    @State private var workspace = IOSWorkspace()

    init() {
        IOSImageSourceStaging.removeAbandonedFiles()
        FontCatalog.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup { IOSRootView(workspace: workspace).preferredColorScheme(.light) }
    }
}
