import SwiftUI

@main struct KLTImageIOSApp: App {
    @State private var workspace = IOSWorkspace()

    init() {
        IOSImageSourceStaging.removeAbandonedFiles()
        Task.detached { _ = BatchStorage.shared }
    }

    var body: some Scene {
        WindowGroup { IOSRootView(workspace: workspace).preferredColorScheme(.light) }
    }
}
