import KLTCore
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ExportFile: FileDocument {
    static var readableContentTypes: [UTType] { [.png, .tiff, .jpeg, .json] }
    let data: Data
    let ticket: IOSExportTicket?
    init(data: Data, ticket: IOSExportTicket? = nil) {
        self.data = data
        self.ticket = ticket
    }
    init(prepared: PreparedIOSExport) {
        self.init(data: prepared.data, ticket: prepared.ticket)
    }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        ticket = nil
    }
    func validatedData() throws -> Data {
        guard ticket?.isValid ?? true else { throw IOSWorkspaceError.staleResult }
        return data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try validatedData())
    }
}

private enum DetailSheet: String, Identifiable { case analysis, record, coordinates, library
    var id: String { rawValue }
}

struct IOSRootView: View {
    let workspace: IOSWorkspace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var batch: BatchModel?
    @State private var tab = 0
    @State private var sheet: DetailSheet?
    @State private var sourceChoice = false
    @State private var photosPicker = false
    @State private var filesPicker = false
    @State private var drawingSample = false
    @State private var exportFile: ExportFile?
    @State private var exportType: UTType = .png
    @State private var exportName = "KLT Image"
    @State private var showingExporter = false

    var body: some View {
        TabView(selection: $tab) {
            Tab("Workspace", systemImage: "photo.on.rectangle", value: 0) {
                NavigationStack { workspaceScreen }
            }
            Tab("Library", systemImage: "square.stack", value: 1) {
                NavigationStack { IOSLibraryView(workspace: workspace, export: exportMethod) }
            }
        }
        .toolbarBackground(IOSPalette.surface, for: .tabBar)
        .tint(IOSPalette.accent)
        .background(IOSPalette.surface)
        .task { await workspace.loadLibrary() }
        .confirmationDialog("Open image", isPresented: $sourceChoice) {
            Button("Photos") { photosPicker = true }
            Button("Files") { filesPicker = true }
        } message: { Text("Choose one complete original image for local analysis.") }
        .fileImporter(isPresented: $filesPicker, allowedContentTypes: [.jpeg, .png, .tiff, .heic]) { outcome in
            switch outcome {
            case let .success(url): workspace.importImage(url)
            case let .failure(error): workspace.presentError("Files could not provide the image: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: Binding(get: { batch != nil }, set: { if !$0 { batch?.dismiss { batch = nil } } })) {
            IOSReservedSafeContent { _ in
                if let batch { BatchView(model: batch, close: { self.batch = nil }) }
            }.presentationDetents([.large])
        }
        .sheet(isPresented: $photosPicker) {
            PhotosSourcePicker { result in
                photosPicker = false
                switch result {
                case let .success(original):
                    workspace.importImage(original.url, displayName: original.name, removeAfterImport: true)
                case let .failure(error):
                    if !(error is CancellationError) { workspace.presentError(error.localizedDescription) }
                }
            }
        }
        .sheet(item: $sheet) { destination in
            NavigationStack {
                Group {
                    switch destination {
                    case .analysis: AnalysisDetail(workspace: workspace, drawingSample: $drawingSample, openCoordinates: { sheet = .coordinates })
                    case .record: RecordDetail(workspace: workspace, export: exportRecord)
                    case .coordinates: CoordinatesDetail(workspace: workspace)
                    case .library: IOSLibraryView(workspace: workspace, export: exportMethod)
                    }
                }
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { sheet = nil } } }
            }
            .presentationDetents([.medium, .large])
        }
        .fileExporter(isPresented: $showingExporter, document: exportFile,
                      contentType: exportType, defaultFilename: exportName) { outcome in
            if case let .failure(error) = outcome, exportFile?.ticket?.isValid != false {
                workspace.presentError("The document could not be saved: \(error.localizedDescription). Current work is unchanged.")
            }
            exportFile?.ticket?.invalidate()
            exportFile = nil
        }
        .onChange(of: workspace.exportRevision) { _, _ in
            if exportFile?.ticket?.isValid == false {
                showingExporter = false
                exportFile = nil
            }
        }
        .alert("KLT Image", isPresented: Binding(
            get: { workspace.error != nil },
            set: { if !$0 { workspace.dismissError() } }
        )) { Button("OK") { workspace.dismissError() } } message: {
            Text(workspace.error ?? "")
        }
    }

    private var workspaceScreen: some View {
        GeometryReader { geometry in
            let inspector = showsInspector(geometry)
            if #available(iOS 27.1, *), inspector {
                ArrangementView {
                    IOSReservedSafeContent { size in workspaceContent(size: size, inspector: inspector) }
                        .splitArrangementLayoutSize(minWidth: 280, idealWidth: 560, minHeight: 280)
                } secondary: {
                    analysisInspector.splitArrangementLayoutSize(minWidth: 240, idealWidth: 280, maxWidth: 340, minHeight: 280)
                }
                .arrangementViewStyle(.split)
            } else if #available(iOS 27.1, *) {
                IOSReservedSafeContent { size in workspaceContent(size: size, inspector: false) }
            } else {
                HStack(spacing: 0) {
                    workspaceContent(size: CGSize(width: geometry.size.width - (inspector ? 281 : 0),
                                                  height: geometry.size.height), inspector: inspector)
                    if inspector { Divider(); analysisInspector.frame(width: 280) }
                }
            }
        }
        .navigationTitle("KLT Image")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Open image", systemImage: "plus") { sourceChoice = true }
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Analysis record", systemImage: "doc.text") { sheet = .record }
                    .disabled(workspace.currentResult == nil)
            }
            if #available(iOS 27.0, *) {
                ToolbarOverflowMenu { workspaceActions }
            } else {
                ToolbarItem(placement: .topBarLeading) {
                    Menu { workspaceActions } label: {
                        Label("Workspace actions", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .foregroundStyle(IOSPalette.inkStrong)
    }

    private func showsInspector(_ geometry: GeometryProxy) -> Bool {
        let divisions: [CGRect]
        if #available(iOS 27.1, *) { divisions = geometry.reservedRegions(kind: .division).map(\.frame) }
        else { divisions = [] }
        return workspace.source != nil && sheet == nil && IOSWorkspaceLayout.showsInspector(
            size: geometry.size, regularWidth: horizontalSizeClass == .regular,
            accessibilityText: textSize.isAccessibilitySize, divisions: divisions)
    }

    private var analysisInspector: some View {
        IOSReservedSafeContent { _ in
            ScrollView {
                AnalysisInspector(workspace: workspace, openAnalysis: { sheet = .analysis },
                                  openRecord: { sheet = .record }, exportImage: exportImage, exportRecord: exportRecord)
            }
            .background(IOSPalette.surface)
            .accessibilityIdentifier("analysis-inspector")
        }
    }

    @ViewBuilder private var workspaceActions: some View {
        Button("Methods", systemImage: "square.stack") { sheet = .library }
        Button("Batch processing", systemImage: "square.stack.3d.up") {
            batch = BatchModel(library: { workspace.library }, workspaceBusy: { workspace.batchBusy })
        }.disabled(BatchWorkspaceLease.shared.isPresented)
        Divider()
        if let url = IOSReleaseLinks.privacy { Link(destination: url) { Label("Privacy policy", systemImage: "hand.raised") } }
        if let url = IOSReleaseLinks.support { Link(destination: url) { Label("Support", systemImage: "questionmark.circle") } }
    }

    private func workspaceContent(size: CGSize, inspector: Bool) -> some View {
        // This ScrollView keeps all controls reachable at short heights and the
        // largest text sizes. Canvas height is an allocation, never a bar offset.
        ScrollView {
            VStack(spacing: 0) {
                if workspace.source == nil {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.artframe").font(.system(size: 44)).foregroundStyle(IOSPalette.accent)
                        Text("Reveal subtle color structure").font(IOSFont.display())
                        Text("Choose a photograph. Analysis stays on this device, and the source stays unchanged.")
                            .font(IOSFont.body()).foregroundStyle(IOSPalette.ink)
                        Button("Open image") { sourceChoice = true }.buttonStyle(IOSActionButtonStyle(primary: true))
                    }
                    .multilineTextAlignment(.center).padding(24)
                    .frame(maxWidth: .infinity, minHeight: size.height)
                } else {
                    Text(workspace.sourceName).font(IOSFont.label(14)).lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.top, 8)
                    comparisonControl
                    RegisteredCanvas(workspace: workspace, drawingSample: $drawingSample)
                        .frame(height: max(160, size.height - (inspector ? 220 : 340)))
                    if workspace.isProcessing || workspace.isImporting || workspace.isPreparingExport {
                        ViewThatFits(in: .horizontal) {
                            HStack { busyMessage; cancelButton }
                            VStack { busyMessage; cancelButton }
                        }
                        .padding(8).background(IOSPalette.surfaceTint)
                    }
                    canvasControls
                    metadataStrip
                    if !inspector { compactSummary }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var busyMessage: some View {
        Label(workspace.isImporting ? "Opening original…" : workspace.isProcessing ? "Processing…" : "Preparing export…",
              systemImage: "hourglass").font(IOSFont.label())
    }
    private var cancelButton: some View {
        Button("Cancel") { workspace.cancel() }.frame(minWidth: 44, minHeight: 44)
    }

    private var comparisonBinding: Binding<IOSComparisonMode> {
        Binding(get: { workspace.comparison }, set: { value in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { workspace.comparison = value }
        })
    }

    private var comparisonControl: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                ForEach(IOSComparisonMode.allCases) { mode in
                    Button(mode.rawValue) { comparisonBinding.wrappedValue = mode }
                        .font(IOSFont.label(12)).fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 10).frame(minHeight: 44)
                        .foregroundStyle(IOSPalette.inkStrong)
                        .background(workspace.comparison == mode ? IOSPalette.surface : IOSPalette.surfaceTint,
                                    in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityAddTraits(workspace.comparison == mode ? .isSelected : [])
                }
            }
            Picker("Comparison", selection: comparisonBinding) {
                ForEach(IOSComparisonMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu).frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
        .padding(4).background(IOSPalette.surfaceTint, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(IOSPalette.divider, lineWidth: 1)).padding(8)
    }

    private var zoomControls: some View {
        HStack(spacing: 2) {
            Button("Zoom out", systemImage: "minus") { workspace.zoomOut() }
                .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
            Text("\(Int(workspace.zoom * 100))%").font(IOSFont.mono())
                .accessibilityLabel("Zoom \(Int(workspace.zoom * 100)) percent")
            Button("Zoom in", systemImage: "plus") { workspace.zoomIn() }
                .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
            Button("Fit") { workspace.fit() }.frame(minWidth: 44, minHeight: 44)
        }.fixedSize(horizontal: true, vertical: false)
    }
    private var drawButton: some View {
        Button(drawingSample ? "Drawing…" : "Draw sample", systemImage: "rectangle.dashed") {
            drawingSample.toggle()
            if drawingSample { workspace.comparison = .original }
        }.frame(minHeight: 44)
    }
    private var coordinatesButton: some View {
        Button("Coordinates", systemImage: "number") { sheet = .coordinates }.frame(minHeight: 44)
    }
    private var sampleMenu: some View {
        Menu { drawButton; coordinatesButton } label: {
            Label("Sample actions", systemImage: "ellipsis").labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
        }
    }
    private var canvasControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { zoomControls; drawButton; coordinatesButton }.fixedSize(horizontal: true, vertical: false)
            HStack(spacing: 8) { zoomControls; sampleMenu }.fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 4) { zoomControls; sampleMenu }
        }
        .font(IOSFont.label(12)).buttonStyle(IOSCanvasButtonStyle()).foregroundStyle(IOSPalette.inkStrong)
        .padding(8).frame(maxWidth: .infinity).background(IOSPalette.surface)
    }

    private var metadataStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(workspace.methodName) · \(workspace.isReplayed ? "replayed" : workspace.matrixMode.displayName.lowercased()) · \(workspace.sampleSource.displayName.lowercased())")
            Text("Source unchanged. Enhanced color is exploratory evidence. Lighting, noise, compression and clipping can influence appearance.")
                .foregroundStyle(IOSPalette.ink)
        }
        .font(IOSFont.label(10)).fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading).background(IOSPalette.surfaceTint)
        .accessibilityElement(children: .combine)
    }

    private var compactSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(workspace.currentResult == nil ? "Waiting for analysis" : workspace.isReplayed ? "Replayed saved transform" : "Calculated for this image")
                .font(IOSFont.label(14))
            Text(workspace.status).font(IOSFont.body(11)).foregroundStyle(IOSPalette.ink)
            ViewThatFits(in: .horizontal) {
                HStack { summaryActions }.fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading) { summaryActions }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).background(IOSPalette.surface)
        .accessibilityIdentifier("analysis-summary")
    }
    @ViewBuilder private var summaryActions: some View {
        Button("Analysis") { sheet = .analysis }.buttonStyle(IOSActionButtonStyle())
        Button("Export result") { exportImage() }.buttonStyle(IOSActionButtonStyle(primary: true)).disabled(workspace.currentResult == nil)
    }

    private func exportImage() {
        sheet = .analysis
    }

    private func exportRecord() {
        Task {
            do {
                let prepared = try await workspace.prepareRecordFileExport()
                guard workspace.isCurrent(prepared) else { throw IOSWorkspaceError.staleResult }
                offerExport(prepared, type: .json, name: "\((workspace.sourceName as NSString).deletingPathExtension)-klt.klt-analysis")
            } catch is CancellationError {
                // Cancel has already updated the workspace status.
            } catch { workspace.presentError(error.localizedDescription) }
        }
    }

    private func exportMethod(_ data: Data, type: UTType, name: String) {
        offerExport(data, type: type, name: name)
    }

    private func offerExport(_ data: Data, type: UTType, name: String) {
        exportFile = ExportFile(data: data)
        exportType = type
        exportName = name
        showingExporter = true
    }

    private func offerExport(_ prepared: PreparedIOSExport, type: UTType, name: String) {
        exportFile = ExportFile(prepared: prepared)
        exportType = type
        exportName = name
        showingExporter = true
    }
}

private struct AnalysisInspector: View {
    let workspace: IOSWorkspace
    let openAnalysis: () -> Void
    let openRecord: () -> Void
    let exportImage: () -> Void
    let exportRecord: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ANALYSIS").font(IOSFont.mono()).foregroundStyle(IOSPalette.inkMuted)
            Text(workspace.source == nil ? "No analysis yet"
                 : workspace.currentResult == nil ? "Waiting for analysis"
                 : workspace.isReplayed ? "Replayed transform" : "Calculated for this image")
                .font(IOSFont.display(19))
            Divider()
            LabeledContent("Working space", value: workspace.methodName)
            LabeledContent("Matrix", value: workspace.matrixMode.displayName)
            LabeledContent("Sample", value: workspace.sampleSource.displayName)
            if let source = workspace.source {
                LabeledContent("Source", value: "\(source.width) × \(source.height)")
            }
            Button("Change analysis") { openAnalysis() }.frame(minHeight: 44)
            Button("Inspect record") { openRecord() }.frame(minHeight: 44).disabled(workspace.currentResult == nil)
            Button("Export record") { exportRecord() }.frame(minHeight: 44).disabled(workspace.currentResult == nil)
            Button("Export result") { exportImage() }
                .buttonStyle(IOSActionButtonStyle(primary: true)).disabled(workspace.currentResult == nil)
            Text("Enhanced color is exploratory evidence.")
                .font(IOSFont.body(11)).foregroundStyle(IOSPalette.inkMuted)
        }
        .font(IOSFont.body(12))
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AnalysisDetail: View {
    let workspace: IOSWorkspace
    @Binding var drawingSample: Bool
    let openCoordinates: () -> Void
    @State private var format: ImageExportFormat = .png
    @State private var exportFile: ExportFile?
    @State private var showingExporter = false
    var body: some View {
        Form {
            Section("Method") {
                if workspace.isReplayed {
                    LabeledContent("Saved transform", value: workspace.methodName)
                    Button("Calculate for This Image") { workspace.calculateForThisImage() }
                } else {
                    Picker("Working space", selection: Binding(
                        get: { workspace.methodName },
                        set: { name in
                            if let item = WorkingSpaceCatalog.allBuiltIn.first(where: { $0.libraryName == name }) { workspace.chooseSpace(item) }
                            else if let item = workspace.library.userWorkingSpaces.first(where: { $0.libraryName == name }) { workspace.chooseSpace(item) }
                        }
                    )) {
                        ForEach(WorkingSpaceCatalog.allBuiltIn, id: \.libraryName) { Text($0.libraryName).tag($0.libraryName) }
                        ForEach(workspace.library.userWorkingSpaces, id: \.libraryName) { Text($0.libraryName).tag($0.libraryName) }
                    }
                    Picker("Matrix", selection: Binding(get: { workspace.matrixMode }, set: { workspace.matrixMode = $0 })) {
                        ForEach(AnalysisMatrixMode.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Statistics from", selection: Binding(get: { workspace.sampleSource }, set: { workspace.sampleSource = $0 })) {
                        ForEach(AnalysisSampleSource.allCases) { Text($0.displayName).tag($0) }
                    }
                }
            }
            Section("Sample") {
                Text("Statistics come from the rectangle; its transform applies to the full image.")
                Button("Draw sample on source") { workspace.comparison = .original; drawingSample = true }
                Button("Exact source pixels") { openCoordinates() }
                if workspace.region != nil { Button("Clear sample") { workspace.clearRegion() } }
            }
            Section("Export") {
                Picker("Image format", selection: $format) {
                    ForEach(ImageExportFormat.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                if let source = workspace.source {
                    Text("Full resolution: \(source.width) × \(source.height) pixels. PNG and TIFF retain alpha; JPEG flattens it.")
                }
                Button("Export result") { prepareExport() }.disabled(workspace.currentResult == nil)
            }
        }
        .navigationTitle("Analysis")
        .font(IOSFont.body())
        .fileExporter(isPresented: $showingExporter, document: exportFile,
                      contentType: format.uniformType,
                      defaultFilename: "\((workspace.sourceName as NSString).deletingPathExtension)-klt") { outcome in
            if case let .failure(error) = outcome, exportFile?.ticket?.isValid != false {
                workspace.presentError(error.localizedDescription)
            }
            exportFile?.ticket?.invalidate()
            exportFile = nil
        }
        .onChange(of: workspace.exportRevision) { _, _ in
            if exportFile?.ticket?.isValid == false {
                showingExporter = false
                exportFile = nil
            }
        }
    }

    private func prepareExport() {
        Task {
            do {
                let prepared = try await workspace.prepareImageFileExport(format)
                guard workspace.isCurrent(prepared) else { throw IOSWorkspaceError.staleResult }
                exportFile = ExportFile(prepared: prepared)
                showingExporter = true
            } catch is CancellationError {
                // Cancel has already updated the workspace status.
            } catch { workspace.presentError(error.localizedDescription) }
        }
    }
}

private struct CoordinatesDetail: View {
    let workspace: IOSWorkspace
    @Environment(\.dismiss) private var dismiss
    @State private var x = ""
    @State private var y = ""
    @State private var width = ""
    @State private var height = ""
    @State private var validationMessage: String?
    @State private var initialized = false
    var body: some View {
        Form {
            Section("Exact source pixels") {
                TextField("X", text: $x).keyboardType(.numberPad)
                TextField("Y", text: $y).keyboardType(.numberPad)
                TextField("Width", text: $width).keyboardType(.numberPad)
                TextField("Height", text: $height).keyboardType(.numberPad)
                Text("Top-left origin. Bounds are half-open and must contain at least four pixels.")
                    .font(IOSFont.body(12))
                Button("Use rectangle") {
                    guard let x = Int(x), let y = Int(y), let width = Int(width), let height = Int(height) else {
                        validationMessage = "Enter whole source-pixel values in all four fields."
                        return
                    }
                    let proposed = SourcePixelRegion(x: x, y: y, width: width, height: height)
                    guard let source = workspace.source else { return }
                    do {
                        _ = try SourcePixelRegionValidator.validate(proposed, sourceWidth: source.width, sourceHeight: source.height)
                        workspace.setRegion(proposed)
                        validationMessage = nil
                        dismiss()
                    } catch { validationMessage = error.localizedDescription }
                }
                if let validationMessage { Text(validationMessage).foregroundStyle(IOSPalette.warning) }
            }
        }
        .navigationTitle("Sample coordinates")
        .onAppear {
            guard !initialized else { return }
            initialized = true
            if let region = workspace.region {
                x = String(region.x); y = String(region.y)
                width = String(region.width); height = String(region.height)
            }
        }
    }
}

private struct RecordDetail: View {
    let workspace: IOSWorkspace
    let export: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(workspace.isReplayed ? "Replayed saved transform" : "Calculated for this image")
                    .font(IOSFont.display())
                Text("Target: \(workspace.sourceName)")
                if case let .replayed(recipe, _) = workspace.method {
                    Text("Origin: \(recipe.originSource.displayFilename)")
                    Text("Frozen origin values are not statistics measured from this target.")
                }
                Text("Method: \(workspace.methodName)")
                Text("Enhanced color is exploratory evidence. Lighting, noise, compression and clipping can influence appearance.")
                if let result = workspace.currentResult,
                   let bytes = try? AnalysisRecordSnapshotJSONEncoder.data(for: result.record),
                   let json = String(data: bytes, encoding: .utf8) {
                    Text(json).font(IOSFont.mono(10)).textSelection(.enabled)
                        .padding(12).background(IOSPalette.surfaceTint, in: RoundedRectangle(cornerRadius: 8))
                }
                Button("Export record JSON") { export() }.disabled(workspace.currentResult == nil)
            }
            .font(IOSFont.body())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
        .navigationTitle("Analysis record")
    }
}
