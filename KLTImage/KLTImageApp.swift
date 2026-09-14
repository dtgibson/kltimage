import SwiftUI

@main
@MainActor
struct KLTImageApp: App {
    @State private var workspace: WorkspaceModel

    init() {
        FontCatalog.registerBundledFonts()
        _workspace = State(initialValue: WorkspaceModel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: workspace)
#if DEBUG
                .modifier(UITestAccessibilityEnvironment())
#endif
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1_220, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Image…", action: workspace.presentOpenPanel)
                    .keyboardShortcut("o", modifiers: .command)
                    .disabled(workspace.isBusy)
            }
            CommandGroup(after: .saveItem) {
                Button("Export Result…", action: workspace.presentExportPanel)
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(!workspace.canExport)
            }
            CommandGroup(after: .toolbar) {
                Divider()
                Button("Actual Size", action: workspace.resetView)
                    .keyboardShortcut("0", modifiers: .command)
                    .disabled(workspace.source == nil)
            }
        }
    }
}

#if DEBUG
private struct UITestAccessibilityEnvironment: ViewModifier {
    private let environment = ProcessInfo.processInfo.environment

    @ViewBuilder
    func body(content: Content) -> some View {
        if environment["KLT_UI_TEST_LARGER_TEXT"] == "1" {
            content.environment(\.dynamicTypeSize, .accessibility2)
        } else {
            content
        }
    }
}
#endif
