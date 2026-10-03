import Foundation
import KLTCore
import Observation

@MainActor @Observable
final class BatchModel {
    enum Mode: String, CaseIterable { case calculate = "Calculate each image", replay = "Replay saved transform" }
    let id = UUID()
    var entries: [BatchInputEntry] = []
    var mode: Mode = .calculate
    var spaceID = WorkingSpaceCatalog.standardRGB.id.identifier
    var matrix: AnalysisMatrixMode = .covariance
    var recipeID: UUID?
    var format: ImageExportFormat = .png
    var includesRecord = false
    private(set) var destination: BatchFolderGrant?
    private(set) var destinationDescription = "Selected folder"
    private(set) var runDestinationDescription = "Selected folder"
    private(set) var proposalOwner = UUID()
    private(set) var proposedFolder = ""
    private(set) var ready = false
    private(set) var waiting = true
    private(set) var running = false
    private(set) var stopping = false
    private(set) var finished = false
    private(set) var outcomes: [BatchOutcome] = []
    private(set) var run: BatchRunRequest?
    private(set) var resultFolder: URL?
    private(set) var stopReason: String?
    private(set) var receipts: [BatchTemporaryReceipt] = []
    var notice: String?
    var picking = false
    var selectionGeneration = UUID()
    private var dismissed = false
    private var storage: BatchStorage?
    private var worker: Task<BatchRunResult, Never>?
    private var stopToken: BatchStop?
    private var closeWhenDrained: (() -> Void)?
    let library: () -> MethodLibrarySnapshot
    let workspaceBusy: () -> Bool

    init(library: @escaping () -> MethodLibrarySnapshot, workspaceBusy: @escaping () -> Bool) {
        self.library = library; self.workspaceBusy = workspaceBusy
        proposedFolder = BatchNames.folder(owner: proposalOwner)
        _ = BatchWorkspaceLease.shared.claimSurface(id)
    }
    var spaces: [WorkingSpaceDescriptor] {
        [WorkingSpaceCatalog.standardRGB, WorkingSpaceCatalog.standardLabD65] + WorkingSpaceCatalog.curated + library().userWorkingSpaces.map {
            WorkingSpaceDescriptor(libraryName: $0.libraryName, purpose: $0.purpose ?? "", revision: $0.revision)
        }
    }
    var recipes: [SavedTransformItem] { library().savedTransforms }
    var selectedRecipe: SavedTransformItem? { recipes.first { $0.id == recipeID } }
    var debt: Int { receipts.reduce(0) { $0 + $1.reservedBytes } }
    var settledCount: Int { outcomes.filter { $0.status.settled }.count }
    var heading: String {
        if stopping { return "Stopping…" }
        if finished {
            if let stopReason { return stopReason }
            return outcomes.allSatisfy { $0.status.successful } ? "Batch complete" : "Finished with errors"
        }
        if let active = outcomes.first(where: { [.acquiring, .processing, .saving].contains($0.status) }) {
            return "\(active.status.rawValue) image \(active.ordinal) of \(outcomes.count)"
        }
        return running ? "Preparing output folder…" : "Batch processing"
    }
    var disabledReason: String? {
        if waiting { return "Waiting for the current operation…" }
        if !ready { return "Temporary storage is unavailable. Review the message above." }
        if picking { return "Adding selected images…" }
        if entries.count > 100 { return "Remove images until no more than 100 remain." }
        if entries.isEmpty || !entries.contains(where: { $0.selectionError == nil }) { return "Add an eligible image to begin." }
        do { _ = try method() } catch { return error.localizedDescription }
        if destination == nil { return "Choose a folder for the results." }
        do { try storage?.requireRoom(BatchLimits.current.sourceBytes) } catch { return error.localizedDescription }
        return nil
    }
    func prepare() async {
        while true {
            guard !Task.isCancelled, !dismissed else { return }
            if !BatchInteractiveWork.shared.busy && !workspaceBusy() && BatchWorkspaceLease.shared.acquire(id) { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        waiting = false
        do {
            let value = try await Task.detached { try BatchStorage.shared.get() }.value
            guard !Task.isCancelled, !dismissed else { BatchWorkspaceLease.shared.release(id); return }
            storage = value; receipts = value.receipts; ready = true
        } catch { notice = "Temporary storage could not be prepared: \(error.localizedDescription)" }
    }
    func add(_ addition: [BatchInputEntry], generation: UUID) {
        guard generation == selectionGeneration, !running, !finished else { return }
        picking = false
        guard addition.count <= 100 - entries.count else { notice = "That selection exceeds 100 images. No images were added."; return }
        entries.append(contentsOf: addition)
    }
    func chooseDestination(_ url: URL) {
        do {
            let grant = try BatchFolderGrant(url)
            destination = grant; notice = nil
            destinationDescription = BatchDestinationLabel.describe(basename: url.lastPathComponent, localizedName: nil)
            Task {
                let description = await Task.detached { BatchDestinationLabel.resolve(grant.url) }.value
                if destination === grant { destinationDescription = description }
            }
        }
        catch { notice = error.localizedDescription }
    }
    func cleanup(_ url: URL) {
        guard !running, let storage else { return }
        do {
            let grant = try BatchFolderGrant(url); picking = true
            Task {
                do {
                    let released = try await Task.detached { try storage.cleanupReselected(grant) }.value
                    notice = "Temporary output cleaned up. \(released) bytes released."
                } catch { notice = error.localizedDescription }
                receipts = storage.receipts; picking = false
            }
        } catch { notice = error.localizedDescription }
    }
    private func method() throws -> (EnhancementExecutionRequest, String) {
        if mode == .replay {
            guard let recipe = selectedRecipe else { throw BatchFailure.item("Choose a saved transform. Close Batch to create or import one in Methods.") }
            try TransformRecipeValidator.validate(recipe.recipe, libraryName: recipe.libraryName)
            return (.replayed(recipe.recipe), recipe.libraryName)
        }
        guard let space = spaces.first(where: { $0.id.identifier == spaceID }) else { throw BatchFailure.item("Choose an available working space.") }
        _ = try WorkingSpaceValidator.validate(space.revision)
        let selection: WorkingSpaceSelection = space.id == WorkingSpaceCatalog.standardRGB.id ? .standardRGB
            : space.id == WorkingSpaceCatalog.standardLabD65.id ? .standardLabD65 : .affine(space.revision)
        return (.calculated(.init(workingSpace: selection, matrixMode: matrix, sampleSource: .wholeImage, region: nil)), space.libraryName)
    }
    func start() {
        guard !running, !finished, disabledReason == nil, let storage, let destination else { return }
        do {
            let (execution, name) = try method()
            let request = BatchRunRequest(id: proposalOwner, entries: entries, execution: execution,
                                          methodName: name, modeName: mode.rawValue, format: format,
                                          includesRecord: includesRecord, destination: destination,
                                          folderName: proposedFolder, limits: .current)
            let token = BatchStop(); stopToken = token; run = request
            runDestinationDescription = destinationDescription
            outcomes = entries.enumerated().map { BatchOutcome(id: $0.element.id, ordinal: $0.offset + 1, name: $0.element.name) }
            running = true; stopping = false; notice = nil; stopReason = nil
            let controller = self
            worker = Task.detached(priority: .userInitiated) {
                await BatchRunner.run(request, storage: storage, stop: token, prepared: { folder in
                    Task { @MainActor in
                        if controller.run?.id == request.id { controller.resultFolder = folder }
                    }
                }, phase: { index, phase in
                    Task { @MainActor in
                        let model = controller
                        guard model.run?.id == request.id, model.running,
                              !model.outcomes[index].status.settled else { return }
                        model.outcomes[index].status = phase
                    }
                }, settled: { row in
                    Task { @MainActor in
                        let model = controller
                        guard model.run?.id == request.id, let index = model.outcomes.firstIndex(where: { $0.id == row.id }) else { return }
                        model.outcomes[index] = row
                    }
                })
            }
            Task {
                guard let result = await worker?.value else { return }
                outcomes = result.outcomes; stopReason = result.stopReason; resultFolder = result.folder
                running = false; stopping = false; finished = true; worker = nil; stopToken = nil
                receipts = storage.receipts
                if let closeWhenDrained { self.closeWhenDrained = nil; dismiss(closeWhenDrained) }
            }
        } catch { notice = error.localizedDescription }
    }
    func stop(interrupted: Bool = false) {
        guard running else { return }
        stopping = true
        stopToken?.stop(interrupted ? "Batch interrupted" : "Batch canceled")
        worker?.cancel()
    }
    func returnToSetup() {
        guard !running else { return }
        finished = false; outcomes = []; run = nil; resultFolder = nil; stopReason = nil
        proposalOwner = UUID(); proposedFolder = BatchNames.folder(owner: proposalOwner)
        notice = "Starting again processes all listed images into a new folder. Remove already handled entries before starting."
    }
    func dismiss(_ completion: @escaping () -> Void) {
        selectionGeneration = UUID()
        if running { closeWhenDrained = completion; stop(); return }
        dismissed = true
        entries = []; destination = nil; run = nil
        BatchWorkspaceLease.shared.release(id); completion()
    }
}
