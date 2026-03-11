// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import Foundation
import SwiftUI

struct AlertInfo: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

enum RunState {
    case idle
    case running
    case completed
    case cancelled
    case failed

    var displayName: String {
        displayName(language: .french)
    }

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .idle:
            return LocalizationService.tr("run.status.idle", language: language)
        case .running:
            return LocalizationService.tr("run.status.running", language: language)
        case .completed:
            return LocalizationService.tr("run.status.completed", language: language)
        case .cancelled:
            return LocalizationService.tr("run.status.cancelled", language: language)
        case .failed:
            return LocalizationService.tr("run.status.failed", language: language)
        }
    }

    var color: Color {
        switch self {
        case .idle:
            return .secondary
        case .running:
            return .blue
        case .completed:
            return .green
        case .cancelled:
            return .orange
        case .failed:
            return .red
        }
    }
}

@MainActor
final class MainViewModel: ObservableObject {
    @Published var sourceFolderURL: URL? {
        didSet { persistSettings() }
    }
    @Published var outputFolderURL: URL? {
        didSet { persistSettings() }
    }

    @Published var includeSubdirectories: Bool = true {
        didSet { persistSettings() }
    }
    @Published var useSeparateOutputFolder: Bool = false {
        didSet { persistSettings() }
    }
    @Published var preserveRelativeStructure: Bool = false {
        didSet { persistSettings() }
    }
    @Published var dryRunOnly: Bool = false {
        didSet { persistSettings() }
    }
    @Published var ignoreHiddenFiles: Bool = true {
        didSet { persistSettings() }
    }
    @Published var appLanguage: AppLanguage = .french {
        didSet { persistSettings() }
    }

    @Published var selectedProfileID: String? {
        didSet { persistSettings() }
    }
    @Published var profileSearchText: String = "" {
        didSet { ensureSelectedProfileFitsSearch() }
    }
    @Published var collisionPolicy: CollisionPolicy = .skipExisting {
        didSet { persistSettings() }
    }

    @Published var libreOfficePath: String = "" {
        didSet { persistSettings() }
    }
    @Published var libreOfficeFound: Bool = false
    @Published var libreOfficeVersion: String = ""
    @Published var libreOfficeMessage: String = "Non vérifié"

    @Published var logs: [LogEntry] = []
    @Published var stats = ConversionStats()
    @Published var progress: Double = 0
    @Published var progressMessage: String = "Prêt"
    @Published var isRunning: Bool = false
    @Published var runState: RunState = .idle
    @Published var runSummary: String = "Aucun traitement exécuté."

    @Published var alertInfo: AlertInfo?

    let profiles = ConversionProfile.all

    private let settingsStore: SettingsStore
    private let libreOfficeLocator: LibreOfficeLocator
    private let coordinator: ConversionCoordinator

    private var runTask: Task<Void, Never>?

    init(
        settingsStore: SettingsStore = SettingsStore(),
        libreOfficeLocator: LibreOfficeLocator = LibreOfficeLocator(),
        coordinator: ConversionCoordinator = ConversionCoordinator(),
        autoDetectLibreOffice: Bool = true
    ) {
        self.settingsStore = settingsStore
        self.libreOfficeLocator = libreOfficeLocator
        self.coordinator = coordinator

        loadSettings()
        progressMessage = tr("progress.ready")
        runSummary = tr("summary.none")
        if autoDetectLibreOffice {
            refreshLibreOfficeStatus()
        }
    }

    var selectedProfile: ConversionProfile? {
        ConversionProfile.byID(selectedProfileID)
    }

    var uiLocale: Locale {
        Locale(identifier: appLanguage.localeIdentifier)
    }

    func tr(_ key: String) -> String {
        LocalizationService.tr(key, language: appLanguage)
    }

    func tr(_ key: String, _ args: CVarArg...) -> String {
        LocalizationService.tr(key, language: appLanguage, args)
    }

    func tr(_ key: String, args: [CVarArg]) -> String {
        LocalizationService.tr(key, language: appLanguage, args)
    }

    var filteredProfiles: [ConversionProfile] {
        let query = profileSearchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !query.isEmpty else {
            return profiles
        }

        return profiles.filter { profile in
            let haystack = [
                profile.displayName.lowercased(),
                profile.id.lowercased(),
                profile.sourceExtensions.joined(separator: ",").lowercased(),
                profile.targetExtension.lowercased(),
                profile.libreOfficeTarget.lowercased()
            ].joined(separator: "|")
            return haystack.contains(query)
        }
    }

    var hasFilteredProfiles: Bool {
        !filteredProfiles.isEmpty
    }

    var profileSummaryLines: [String] {
        guard let selectedProfile else {
            return [tr("summary.profile.none")]
        }

        let sources = selectedProfile.sourceExtensions
            .map { ".\($0)" }
            .joined(separator: ", ")

        return [
            tr("summary.profile.source_filter", sources),
            tr("summary.profile.target_extension", selectedProfile.targetExtension),
            tr("summary.profile.libreoffice_format", selectedProfile.libreOfficeTarget)
        ]
    }

    var sourcePathText: String {
        sourceFolderURL?.path ?? tr("path.none.source")
    }

    var outputPathText: String {
        outputFolderURL?.path ?? tr("path.none.output")
    }

    var analysisBlockers: [String] {
        var blockers: [String] = []

        if isRunning {
            blockers.append(tr("blocker.running"))
        }
        if sourceFolderURL == nil {
            blockers.append(tr("blocker.choose_source"))
        }
        if selectedProfile == nil {
            blockers.append(tr("blocker.choose_profile"))
        }
        if useSeparateOutputFolder && outputFolderURL == nil {
            blockers.append(tr("blocker.choose_output"))
        }

        return blockers
    }

    var conversionBlockers: [String] {
        var blockers = analysisBlockers
        if !dryRunOnly && !libreOfficeFound {
            blockers.append(tr("blocker.libreoffice_required"))
        }
        return blockers
    }

    var canAnalyze: Bool {
        analysisBlockers.isEmpty
    }

    var canStartConversion: Bool {
        conversionBlockers.isEmpty
    }

    var sensitiveSettingsLines: [String] {
        let modeText = dryRunOnly ? tr("sensitive.mode.dry") : tr("sensitive.mode.real")
        let yesNo = includeSubdirectories ? tr("common.yes") : tr("common.no")

        return [
            tr("sensitive.mode", modeText),
            tr("sensitive.subdirs", yesNo),
            tr("sensitive.output", outputModeDescription),
            tr("sensitive.tree", preserveTreeDescription),
            tr("sensitive.collision", collisionPolicy.displayName(language: appLanguage))
        ]
    }

    var conversionConfirmationMessage: String {
        let profileName = selectedProfile?.displayName ?? tr("picker.select")
        let sourceLine = tr("dialog.confirm.source", sourcePathText)
        let outputLine = tr("dialog.confirm.output", outputModeDescription)
        let treeLine = tr("dialog.confirm.tree", preserveTreeDescription)
        let collisionLine = tr("dialog.confirm.collision", collisionPolicy.displayName(language: appLanguage))
        let modeLine = dryRunOnly ? tr("dialog.confirm.mode.dry") : tr("dialog.confirm.mode.real")

        return [
            tr("dialog.confirm.profile", profileName),
            modeLine,
            sourceLine,
            outputLine,
            treeLine,
            collisionLine,
            "",
            tr("dialog.confirm.no_modify"),
            tr("dialog.confirm.continue")
        ].joined(separator: "\n")
    }

    var activeOutputFolder: URL? {
        if useSeparateOutputFolder {
            return outputFolderURL
        }
        return sourceFolderURL
    }

    private var outputModeDescription: String {
        if useSeparateOutputFolder {
            return outputFolderURL?.path ?? tr("output_mode.separate_undefined")
        }
        return tr("output_mode.same_as_source")
    }

    private var preserveTreeDescription: String {
        if useSeparateOutputFolder {
            return preserveRelativeStructure ? tr("tree.preserved") : tr("tree.not_preserved")
        }
        return tr("tree.not_applicable")
    }

    func chooseSourceFolder() {
        let panel = NSOpenPanel()
        panel.title = tr("panel.source.title")
        panel.message = tr("panel.source.message")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK {
            sourceFolderURL = panel.url
        }
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.title = tr("panel.output.title")
        panel.message = tr("panel.output.message")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK {
            outputFolderURL = panel.url
        }
    }

    func refreshLibreOfficeStatus() {
        let preferred = libreOfficePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let info = libreOfficeLocator.locate(preferredPath: preferred.isEmpty ? nil : preferred)

        libreOfficeFound = info.isFound
        libreOfficeVersion = info.version
        libreOfficeMessage = info.message

        if info.isFound {
            libreOfficePath = info.executablePath
        }
    }

    func testLibreOfficePath() {
        let path = libreOfficePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            alertInfo = AlertInfo(
                title: tr("alert.path_missing"),
                message: tr("alert.path_missing_message")
            )
            return
        }

        let info = libreOfficeLocator.test(path: path)
        libreOfficeFound = info.isFound
        libreOfficeVersion = info.version
        libreOfficeMessage = info.message

        if info.isFound {
            alertInfo = AlertInfo(
                title: tr("alert.libreoffice_found"),
                message: tr("alert.libreoffice_found_message", info.version.isEmpty ? "unknown" : info.version)
            )
        } else {
            alertInfo = AlertInfo(
                title: tr("alert.libreoffice_not_found"),
                message: tr("alert.libreoffice_not_found_message")
            )
        }
    }

    func analyze() {
        do {
            let options = try buildOptions()
            startNewRun(initialMessage: tr("progress.analyzing"))

            runTask = Task {
                do {
                    let computedStats = try await coordinator.analyze(
                        options: options,
                        eventHandler: eventHandler()
                    )
                    self.stats = computedStats
                    finishRun(operationLabel: tr("label.analysis"))
                } catch {
                    handleRunError(error, operationLabel: tr("label.analysis"))
                    finishRun(operationLabel: tr("label.analysis"))
                }
            }
        } catch {
            alertInfo = AlertInfo(title: tr("alert.analyze_impossible"), message: error.localizedDescription)
        }
    }

    func startConversion() {
        do {
            let options = try buildOptions()

            if !options.dryRun && !libreOfficeFound {
                throw MuniConvertError.libreOfficeNotFound
            }

            let executableURL: URL?
            if options.dryRun {
                executableURL = nil
            } else {
                executableURL = URL(fileURLWithPath: libreOfficePath)
            }

            startNewRun(initialMessage: options.dryRun ? tr("progress.simulating") : tr("progress.converting"))
            let operationLabel = options.dryRun ? tr("label.simulation") : tr("label.conversion")

            runTask = Task {
                do {
                    let computedStats = try await coordinator.convert(
                        options: options,
                        libreOfficeExecutable: executableURL,
                        eventHandler: eventHandler()
                    )
                    self.stats = computedStats
                    finishRun(operationLabel: operationLabel)
                } catch {
                    handleRunError(error, operationLabel: operationLabel)
                    finishRun(operationLabel: operationLabel)
                }
            }
        } catch {
            alertInfo = AlertInfo(title: tr("alert.conversion_impossible"), message: error.localizedDescription)
        }
    }

    func stopCurrentRun() {
        guard isRunning else {
            return
        }

        progressMessage = tr("progress.cancelling")
        runSummary = tr("summary.cancelling")

        runTask?.cancel()
        Task {
            await coordinator.cancelCurrentRun()
        }
    }

    func clearLogs() {
        logs.removeAll()
        stats = ConversionStats()
        progress = 0
        progressMessage = tr("progress.ready")
        runState = .idle
        runSummary = tr("summary.none")
    }

    func exportLogs() {
        guard !logs.isEmpty else {
            alertInfo = AlertInfo(title: tr("alert.log_empty"), message: tr("alert.log_empty_message"))
            return
        }

        let panel = NSSavePanel()
        panel.title = tr("panel.export_log.title")
        panel.nameFieldStringValue = defaultLogFileName()
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        do {
            try buildLogText().write(to: destinationURL, atomically: true, encoding: .utf8)
            alertInfo = AlertInfo(
                title: tr("alert.export_success"),
                message: tr("alert.export_success_message", destinationURL.path)
            )
        } catch {
            alertInfo = AlertInfo(
                title: tr("alert.export_failed"),
                message: error.localizedDescription
            )
        }
    }

    func openOutputFolderInFinder() {
        guard let folder = activeOutputFolder else {
            alertInfo = AlertInfo(
                title: tr("alert.no_folder"),
                message: tr("alert.no_folder_message")
            )
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }

    private func startNewRun(initialMessage: String) {
        runTask?.cancel()
        logs.removeAll()
        stats = ConversionStats()
        progress = 0
        progressMessage = initialMessage
        isRunning = true
        runState = .running
        runSummary = tr("summary.running")
    }

    private func finishRun(operationLabel: String) {
        isRunning = false
        if progress < 1 {
            progress = 1
        }

        if runState == .running {
            runState = .completed
        }

        switch runState {
        case .completed:
            progressMessage = tr("run.finished", operationLabel)
            runSummary = buildSummary(prefix: tr("run.finished", operationLabel))
        case .cancelled:
            progressMessage = tr("run.cancelled", operationLabel)
            runSummary = buildSummary(prefix: tr("run.cancelled", operationLabel))
        case .failed:
            if runSummary == tr("summary.running") || runSummary == tr("summary.none") {
                runSummary = tr("run.interrupted", operationLabel)
            }
            progressMessage = tr("run.failed", operationLabel)
        case .idle:
            progressMessage = tr("progress.ready")
            runSummary = tr("summary.none")
        case .running:
            break
        }

        runTask = nil
    }

    private func handleRunError(_ error: Error, operationLabel: String) {
        if let mcError = error as? MuniConvertError, case .cancelled = mcError {
            runState = .cancelled
            runSummary = buildSummary(prefix: tr("run.cancelled", operationLabel))
            return
        }

        runState = .failed
        runSummary = "\(tr("run.interrupted", operationLabel)): \(error.localizedDescription)"
        alertInfo = AlertInfo(title: tr("alert.error"), message: error.localizedDescription)
    }

    private func buildOptions() throws -> ConversionOptions {
        guard let sourceFolderURL else {
            throw MuniConvertError.sourceFolderInvalid(tr("error.source_folder_none"))
        }

        guard let selectedProfile else {
            throw MuniConvertError.invalidProfile
        }

        if useSeparateOutputFolder && outputFolderURL == nil {
            throw MuniConvertError.outputFolderInvalid(tr("error.output_folder_none"))
        }

        return ConversionOptions(
            sourceFolder: sourceFolderURL,
            outputFolder: outputFolderURL,
            useSeparateOutputFolder: useSeparateOutputFolder,
            preserveRelativeStructure: preserveRelativeStructure,
            includeSubdirectories: includeSubdirectories,
            dryRun: dryRunOnly,
            ignoreHiddenFiles: ignoreHiddenFiles,
            collisionPolicy: collisionPolicy,
            profile: selectedProfile
        )
    }

    private func eventHandler() -> ConversionEventHandler {
        return { [weak self] event in
            await self?.handleEvent(event)
        }
    }

    @MainActor
    private func handleEvent(_ event: ConversionEvent) {
        switch event {
        case .log(let entry):
            logs.append(entry)
            stats = deriveStatsFromLogs()
        case .progress(let value, let message):
            progress = min(max(value, 0), 1)
            progressMessage = message
        }
    }

    private func buildSummary(prefix: String) -> String {
        tr(
            "summary.line",
            prefix,
            stats.totalScanned,
            stats.totalMatched,
            stats.converted,
            stats.dryRun,
            stats.ignored,
            stats.skippedExisting,
            stats.errors
        )
    }

    private func deriveStatsFromLogs() -> ConversionStats {
        var derived = ConversionStats()
        derived.totalMatched = logs.reduce(0) { $0 + ($1.status == .matched ? 1 : 0) }
        derived.ignored = logs.reduce(0) { $0 + ($1.status == .ignored ? 1 : 0) }
        derived.converted = logs.reduce(0) { $0 + ($1.status == .converted ? 1 : 0) }
        derived.errors = logs.reduce(0) { $0 + ($1.status == .failed ? 1 : 0) }
        derived.skippedExisting = logs.reduce(0) { $0 + ($1.status == .skippedExisting ? 1 : 0) }
        derived.dryRun = logs.reduce(0) { $0 + ($1.status == .dryRun ? 1 : 0) }
        derived.totalScanned = derived.totalMatched + derived.ignored
        return derived
    }

    private func loadSettings() {
        let stored = settingsStore.load()

        sourceFolderURL = stored.sourcePath.map { URL(fileURLWithPath: $0) }
        outputFolderURL = stored.outputPath.map { URL(fileURLWithPath: $0) }
        includeSubdirectories = stored.includeSubdirectories
        useSeparateOutputFolder = stored.useSeparateOutputFolder
        preserveRelativeStructure = stored.preserveRelativeStructure
        dryRunOnly = stored.dryRun
        ignoreHiddenFiles = stored.ignoreHiddenFiles
        selectedProfileID = stored.selectedProfileID
        collisionPolicy = CollisionPolicy(rawValue: stored.collisionPolicy) ?? .skipExisting
        libreOfficePath = stored.libreOfficePath
        appLanguage = AppLanguage(rawValue: stored.appLanguage ?? AppLanguage.french.rawValue) ?? .french
    }

    private func persistSettings() {
        let settings = StoredSettings(
            sourcePath: sourceFolderURL?.path,
            outputPath: outputFolderURL?.path,
            includeSubdirectories: includeSubdirectories,
            useSeparateOutputFolder: useSeparateOutputFolder,
            preserveRelativeStructure: preserveRelativeStructure,
            dryRun: dryRunOnly,
            ignoreHiddenFiles: ignoreHiddenFiles,
            selectedProfileID: selectedProfileID,
            collisionPolicy: collisionPolicy.rawValue,
            libreOfficePath: libreOfficePath,
            appLanguage: appLanguage.rawValue
        )

        settingsStore.save(settings)
    }

    private func ensureSelectedProfileFitsSearch() {
        guard let selectedProfile else {
            return
        }

        guard !profileSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        if !filteredProfiles.contains(selectedProfile) {
            selectedProfileID = nil
        }
    }

    private func buildLogText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium

        var lines: [String] = []
        lines.append(tr("log.export.header"))
        lines.append(tr("log.export.date", formatter.string(from: Date())))
        lines.append(stats.summaryLine(language: appLanguage))
        lines.append("")

        for entry in logs {
            let date = formatter.string(from: entry.date)
            let line = "[\(date)] [\(entry.status.displayName(language: appLanguage))] source=\(entry.sourcePath) output=\(entry.outputPath) message=\(entry.message)"
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    private func defaultLogFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "MuniConvert-log-\(formatter.string(from: Date())).txt"
    }
}
