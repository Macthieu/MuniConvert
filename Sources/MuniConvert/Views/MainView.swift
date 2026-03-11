// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showRealConversionConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            selectionZone
            conversionZone
            resultsZone
            settingsZone
        }
        .padding(16)
        .frame(minWidth: 1120, minHeight: 760)
        .alert(item: $viewModel.alertInfo) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .confirmationDialog(
            "Confirmer la conversion",
            isPresented: $showRealConversionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Lancer", role: .destructive) {
                viewModel.startConversion()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Les fichiers originaux ne seront pas modifiés, mais de nouveaux fichiers seront créés. Continuer ?")
        }
    }

    private var selectionZone: some View {
        GroupBox("Zone 1 - Sélection") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button("Choisir un dossier") {
                        viewModel.chooseSourceFolder()
                    }
                    Text(viewModel.sourcePathText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                HStack(spacing: 16) {
                    Toggle("Inclure les sous-dossiers", isOn: $viewModel.includeSubdirectories)
                    Toggle("Utiliser un dossier de sortie distinct", isOn: $viewModel.useSeparateOutputFolder)
                }

                HStack(spacing: 16) {
                    Toggle("Préserver l'arborescence", isOn: $viewModel.preserveRelativeStructure)
                        .disabled(!viewModel.useSeparateOutputFolder)
                    Toggle("Simulation seulement (aucune conversion)", isOn: $viewModel.dryRunOnly)
                    Toggle("Ignorer fichiers cachés", isOn: $viewModel.ignoreHiddenFiles)
                }

                HStack {
                    Button("Choisir dossier de sortie") {
                        viewModel.chooseOutputFolder()
                    }
                    .disabled(!viewModel.useSeparateOutputFolder)

                    Text(viewModel.outputPathText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private var conversionZone: some View {
        GroupBox("Zone 2 - Conversion") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Type de conversion")
                    Picker("Type de conversion", selection: $viewModel.selectedProfileID) {
                        Text("Sélectionner...").tag(String?.none)
                        ForEach(viewModel.profiles) { profile in
                            Text(profile.displayName).tag(String?.some(profile.id))
                        }
                    }
                    .frame(width: 280)

                    Text("Collision")
                    Picker("Collision", selection: $viewModel.collisionPolicy) {
                        ForEach(CollisionPolicy.allCases) { policy in
                            Text(policy.displayName).tag(policy)
                        }
                    }
                    .frame(width: 220)
                }

                HStack {
                    Button("Analyser") {
                        viewModel.analyze()
                    }
                    .disabled(!viewModel.canAnalyze)

                    Button("Lancer la conversion") {
                        if viewModel.dryRunOnly {
                            viewModel.startConversion()
                        } else {
                            showRealConversionConfirmation = true
                        }
                    }
                    .disabled(!viewModel.canStartConversion)

                    Button("Arrêter") {
                        viewModel.stopCurrentRun()
                    }
                    .disabled(!viewModel.isRunning)

                    Spacer()

                    if viewModel.dryRunOnly {
                        Text("MODE SIMULATION")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private var resultsZone: some View {
        GroupBox("Zone 3 - Résultats") {
            VStack(alignment: .leading, spacing: 10) {
                ProgressView(value: viewModel.progress)
                Text(viewModel.progressMessage)
                    .font(.caption)

                Table(viewModel.logs) {
                    TableColumn("Fichier source") { entry in
                        Text(entry.sourcePath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .width(min: 320)

                    TableColumn("Statut") { entry in
                        Text(entry.status.displayName)
                    }
                    .width(min: 100, max: 130)

                    TableColumn("Fichier de sortie") { entry in
                        Text(entry.outputPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .width(min: 280)

                    TableColumn("Message") { entry in
                        Text(entry.message)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(minHeight: 260)

                Text(viewModel.stats.summaryLine)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private var settingsZone: some View {
        GroupBox("Zone 4 - Paramètres") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("LibreOffice (soffice)")
                    TextField("Chemin vers soffice", text: $viewModel.libreOfficePath)
                        .textFieldStyle(.roundedBorder)
                    Button("Détecter") {
                        viewModel.refreshLibreOfficeStatus()
                    }
                    Button("Tester LibreOffice") {
                        viewModel.testLibreOfficePath()
                    }
                }

                HStack {
                    Text(viewModel.libreOfficeFound ? "État: trouvé" : "État: non trouvé")
                        .foregroundStyle(viewModel.libreOfficeFound ? .green : .red)
                    if !viewModel.libreOfficeVersion.isEmpty {
                        Text("Version: \(viewModel.libreOfficeVersion)")
                    }
                    if !viewModel.libreOfficeMessage.isEmpty {
                        Text("| \(viewModel.libreOfficeMessage)")
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .font(.caption)

                HStack {
                    Button("Ouvrir le dossier de sortie") {
                        viewModel.openOutputFolderInFinder()
                    }
                    .disabled(viewModel.activeOutputFolder == nil)

                    Button("Exporter le journal (.txt)") {
                        viewModel.exportLogs()
                    }
                    .disabled(viewModel.logs.isEmpty)

                    Button("Effacer le journal") {
                        viewModel.clearLogs()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }
}
