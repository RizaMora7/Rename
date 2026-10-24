//
//  ContentView.swift
//  Rename
//
//  Created by Raul on 10/10/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var presetManager = PresetManager()
    @State private var findText = ""
    @State private var replaceText = ""
    @State private var fileItems: [FileItem] = []
    @State private var protectExtension = true

    // Lote recién aplicado, para poder deshacerlo.
    @State private var lastBatch: [(from: URL, to: URL)] = []

    // Aviso de resultado (renombrados / colisiones / fallos).
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        VStack(spacing: 20) {
            Picker("Cargar Preset:", selection: Binding(
                get: { "" },
                set: { val in
                    if let p = presetManager.presets.first(where: { $0.find == val }) {
                        findText = p.find
                        replaceText = p.replace
                    }
                }

            )) {
                Text("Seleccionar preset").tag("")
                ForEach(presetManager.presets) { preset in
                    Text("\(preset.find) → \(preset.replace)").tag(preset.find)
                }
            }
            .pickerStyle(.menu)

            HStack {
                TextField("Buscar", text: $findText)
                        .textFieldStyle(.roundedBorder) // Esto hará visible el campo
                    TextField("Reemplazar", text: $replaceText)
                        .textFieldStyle(.roundedBorder)
                Button("Guardar Preset") {
                    if presetManager.presets.count < 5 {
                        presetManager.presets.append(RenamePreset(find: findText, replace: replaceText))
                    }
                }
            }
            .padding()

            Toggle("Proteger la extensión de los archivos", isOn: $protectExtension)
                .toggleStyle(.checkbox)
                .frame(maxWidth: .infinity, alignment: .leading)

            Table(fileItems) {
                TableColumn("Nombre Original", value: \.originalName)

                TableColumn("Nuevo Nombre") { item in
                    Text(item.newName)
                        .foregroundColor(item.originalName != item.newName ? .red : .primary)
                        .bold(item.originalName != item.newName)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers)
                return true
            }
            .frame(minHeight: 300)

            HStack {
                Button("Aplicar Renombrado") {
                    applyRenaming()
                }
                .disabled(fileItems.isEmpty)

                Button("Limpiar") {
                    // Vacía la lista de archivos cargados (reinicia la pantalla).
                    // Mantiene los textos "Buscar"/"Reemplazar" para poder cargar
                    // otro grupo con la misma configuración.
                    fileItems = []
                }
                .disabled(fileItems.isEmpty)

                Button("Deshacer") {
                    undoLastBatch()
                }
                .disabled(lastBatch.isEmpty)
            }
        }
        .padding()
        .onChange(of: findText) { _ in updatePreview() }
        .onChange(of: replaceText) { _ in updatePreview() }
        .onChange(of: protectExtension) { _ in updatePreview() }
        .alert("Resultado del renombrado", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    } // <--- Cierre de body

    private func updatePreview() {
        // Recalcula los nombres nuevos sin tocar el disco.
        fileItems = RenameEngine.previewRename(files: fileItems,
                                               find: findText,
                                               replace: replaceText,
                                               protectExtension: protectExtension)
    }

    private func applyRenaming() {
        let outcome = RenameEngine.applyRenaming(items: fileItems,
                                                 protectExtension: protectExtension)
        lastBatch = outcome.renamed

        // Refresca la lista con los nombres reales del disco para los renombrados.
        let toByFrom = Dictionary(uniqueKeysWithValues: outcome.renamed.map { ($0.from, $0.to) })
        fileItems = fileItems.map { item in
            if let newURL = toByFrom[item.url] {
                return FileItem(url: newURL, newName: item.newName, hasAccess: false)
            }
            return item
        }

        // Mensaje de resultado para el usuario.
        var lines: [String] = ["Renombrados: \(outcome.renamed.count)"]
        if outcome.skipped > 0 { lines.append("Sin cambios: \(outcome.skipped)") }
        if !outcome.errors.isEmpty {
            lines.append("Problemas (\(outcome.errors.count)):")
            for e in outcome.errors.prefix(8) {
                lines.append("• \(e.fileName): \(e.reason)")
            }
            if outcome.errors.count > 8 {
                lines.append("… y \(outcome.errors.count - 8) más.")
            }
        }
        alertMessage = lines.joined(separator: "\n")
        showAlert = true
    }

    private func undoLastBatch() {
        let errors = RenameEngine.undo(renamed: lastBatch)

        // Restaura los URLs de la lista a los nombres originales.
        let fromByTo = Dictionary(uniqueKeysWithValues: lastBatch.map { ($0.to, $0.from) })
        fileItems = fileItems.map { item in
            if let originalURL = fromByTo[item.url] {
                return FileItem(url: originalURL, newName: originalURL.lastPathComponent, hasAccess: item.hasAccess)
            }
            return item
        }
        lastBatch = []
        updatePreview()

        if errors.isEmpty {
            alertMessage = "Se revirtió el último lote de renombrados."
        } else {
            var lines = ["Se revirtió el lote con \(errors.count) problema(s):"]
            for e in errors.prefix(8) {
                lines.append("• \(e.fileName): \(e.reason)")
            }
            alertMessage = lines.joined(separator: "\n")
        }
        showAlert = true
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                let gotAccess = url.startAccessingSecurityScopedResource()

                DispatchQueue.main.async {
                    self.fileItems.append(FileItem(url: url, newName: url.lastPathComponent, hasAccess: gotAccess))
                }
            }
        }
    }
} // <--- Cierre de struct ContentView
