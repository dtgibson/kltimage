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
        GeometryReader { geometry in
            if geometry.size.width >= 850 {
                wideLayout
            } else {
                compactLayout
            }
        }
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
        .fullScreenCover(isPresented: Binding(get: { UIDevice.current.userInterfaceIdiom == .phone && batch != nil }, set: { if !$0 { batch?.dismiss { batch = nil } } })) {
            if let batch { BatchView(model: batch, close: { self.batch = nil }) }
        }
        .sheet(isPresented: Binding(get: { UIDevice.current.userInterfaceIdiom != .phone && batch != nil }, set: { if !$0 { batch?.dismiss { batch = nil } } })) {
            if let batch { BatchView(model: batch, close: { self.batch = nil }).presentationDetents([.large]) }
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

    private var compactLayout: some View {
        TabView(selection: $tab) {
            NavigationStack { workspaceScreen }
                .tabItem { Label("Workspace", systemImage: "photo.on.rectangle") }.tag(0)
            NavigationStack { IOSLibraryView(workspace: workspace, export: exportMethod) }
                .tabItem { Label("Library", systemImage: "square.stack") }.tag(1)
        }
        .toolbarBackground(IOSPalette.surface, for: .tabBar)
    }

    private var wideLayout: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("KLT IMAGE").font(IOSFont.mono(11)).foregroundStyle(IOSPalette.inkMuted).padding(.bottom, 16)
                Button("Workspace", systemImage: "photo.on.rectangle") { tab = 0 }
                Button("Library", systemImage: "square.stack") { tab = 1 }
                Spacer()
                Text("Local scientific imaging").font(IOSFont.body(11)).foregroundStyle(IOSPalette.inkMuted)
            }
            .buttonStyle(.plain)
            .padding(16)
            .frame(width: 166).frame(maxHeight: .infinity, alignment: .topLeading)
            .background(IOSPalette.surfaceTint)
            Divider()
            if tab == 0 {
                NavigationStack { workspaceScreen }
                Divider()
                ScrollView { AnalysisInspector(workspace: workspace, openAnalysis: { sheet = .analysis },
                                               openRecord: { sheet = .record }, exportImage: exportImage,
                                               exportRecord: exportRecord) }
                    .frame(width: 266)
                    .background(IOSPalette.surface)
            } else {
                NavigationStack { IOSLibraryView(workspace: workspace, export: exportMethod) }
            }
        }
    }

    private var workspaceScreen: some View {
        VStack(spacing: 0) {
            if workspace.source == nil {
                Spacer()
                Image(systemName: "photo.artframe").font(.system(size: 44)).foregroundStyle(IOSPalette.accent)
                    .padding(20).background(IOSPalette.surfaceTint, in: RoundedRectangle(cornerRadius: 14))
                Text("Reveal subtle color structure").font(IOSFont.display()).padding(.top, 18)
                Text("Choose a photograph. Analysis stays on this device, and the source stays unchanged.")
                    .font(IOSFont.body()).foregroundStyle(IOSPalette.ink).multilineTextAlignment(.center)
                    .padding(.horizontal, 36).padding(.top, 4)
                Button("Open image") { sourceChoice = true }
                    .buttonStyle(PrimaryActionButtonStyle()).padding(.top, 16)
                Spacer()
            } else {
                comparisonControl
                ZStack(alignment: .bottom) {
                    RegisteredCanvas(workspace: workspace, drawingSample: $drawingSample)
                    if workspace.isProcessing || workspace.isImporting || workspace.isPreparingExport {
                        HStack {
                            ProgressView().tint(IOSPalette.accent)
                            Text(workspace.isImporting ? "Opening original…" : workspace.isProcessing ? "Processing…" : "Preparing export…")
                            Button("Cancel") { workspace.cancel() }
                        }
                        .font(IOSFont.label())
                        .padding(10)
                        .background(IOSPalette.surface.opacity(0.97), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.bottom, 63)
                    }
                    canvasControls
                }
                .frame(maxHeight: .infinity)
                metadataStrip
                if tab == 0 { compactSummary }
            }
        }
        .navigationTitle("KLT Image")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("Batch processing") {
                        batch = BatchModel(library: { workspace.library }, workspaceBusy: { workspace.batchBusy })
                    }.disabled(BatchWorkspaceLease.shared.isPresented)
                } label: { Image(systemName: "ellipsis.circle").accessibilityLabel("Workspace actions") }
            }
            ToolbarItem(placement: .topBarLeading) { Button("Methods", systemImage: "square.stack") { sheet = .library } }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Open image", systemImage: "plus") { sourceChoice = true }
                Button("Analysis record", systemImage: "doc.text") { sheet = .record }
                    .disabled(workspace.currentResult == nil)
            }
        }
        .foregroundStyle(IOSPalette.inkStrong)
    }

    private var comparisonControl: some View {
        HStack(spacing: 2) {
            ForEach(IOSComparisonMode.allCases) { mode in
                Button(mode.rawValue) {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { workspace.comparison = mode }
                }
                .font(IOSFont.label(11))
                .foregroundStyle(workspace.comparison == mode ? IOSPalette.inkStrong : IOSPalette.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(workspace.comparison == mode ? IOSPalette.surface : IOSPalette.surfaceTint,
                            in: RoundedRectangle(cornerRadius: 8))
                .accessibilityAddTraits(workspace.comparison == mode ? .isSelected : [])
            }
        }
        .padding(4).background(IOSPalette.surfaceTint, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(IOSPalette.divider, lineWidth: 1))
        .padding(8)
    }

    private var canvasControls: some View {
        HStack(spacing: 2) {
            Button("Zoom out", systemImage: "minus") { workspace.zoomOut() }
                .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
            Text("\(Int(workspace.zoom * 100))%").font(IOSFont.mono())
                .accessibilityLabel("Zoom \(Int(workspace.zoom * 100)) percent")
            Button("Zoom in", systemImage: "plus") { workspace.zoomIn() }
                .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
            Button("Fit") { workspace.fit() }.frame(minWidth: 44, minHeight: 44)
            Divider().frame(height: 24)
            Button(drawingSample ? "Drawing…" : "Draw sample") {
                drawingSample.toggle()
                if drawingSample { workspace.comparison = .original }
            }.frame(minHeight: 44)
            Button("Coordinates") { sheet = .coordinates }.frame(minHeight: 44)
        }
        .font(IOSFont.label(10))
        .buttonStyle(.plain)
        .foregroundStyle(IOSPalette.inkStrong)
        .controlSize(.regular)
        .padding(6)
        .background(IOSPalette.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(IOSPalette.divider, lineWidth: 1))
        .padding(.bottom, 10)
    }

    private var metadataStrip: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(workspace.methodName)
                Text("·")
                Text(workspace.isReplayed ? "replayed" : workspace.matrixMode.displayName.lowercased())
                Text("·")
                Text(workspace.sampleSource.displayName.lowercased())
                Spacer()
                Text(workspace.currentResult == nil ? "WAITING" : workspace.isReplayed ? "REPLAYED" : "CALCULATED")
            }
            Text("Enhanced color is exploratory evidence. Lighting, noise, compression and clipping can influence appearance.")
                .foregroundStyle(IOSPalette.inkMuted)
        }
        .font(IOSFont.label(10))
        .padding(.horizontal, 14).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IOSPalette.surfaceTint)
        .accessibilityElement(children: .combine)
    }

    private var compactSummary: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(workspace.currentResult == nil
                         ? "Waiting for analysis"
                         : workspace.isReplayed ? "Replayed saved transform" : "Calculated for this image")
                        .font(IOSFont.label(14))
                    Text(workspace.status).font(IOSFont.body(11)).foregroundStyle(IOSPalette.inkMuted)
                }
                Spacer()
                Button("Analysis", systemImage: "chevron.right") { sheet = .analysis }.labelStyle(.iconOnly)
            }
            HStack {
                Button("Analysis") { sheet = .analysis }.buttonStyle(SecondaryActionButtonStyle())
                Button("Export result") { exportImage() }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(workspace.currentResult == nil)
            }
        }
        .padding(14).background(IOSPalette.surface)
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
            Button("Change analysis") { openAnalysis() }
            Button("Inspect record") { openRecord() }.disabled(workspace.currentResult == nil)
            Button("Export record") { exportRecord() }.disabled(workspace.currentResult == nil)
            Button("Export result") { exportImage() }
                .buttonStyle(PrimaryActionButtonStyle()).disabled(workspace.currentResult == nil)
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
                        workspace.presentError("Enter whole source-pixel values in all four fields.")
                        return
                    }
                    workspace.setRegion(SourcePixelRegion(x: x, y: y, width: width, height: height))
                    if workspace.error == nil { dismiss() }
                }
            }
        }
        .navigationTitle("Sample coordinates")
        .onAppear {
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
