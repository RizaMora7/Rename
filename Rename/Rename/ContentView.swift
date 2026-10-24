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
            
            Button("Aplicar Renombrado") {
                // 1. Ejecutar el renombrado y guardar solo los que fallaron
                let failedItems = RenameEngine.applyRenaming(items: fileItems)
                
                // 2. ACTUALIZACIÓN: En lugar de reemplazar la lista,
                // refrescamos la lista con los nuevos nombres reales del disco.
                // Esto mantiene los archivos en la vista y actualiza los nombres correctamente.
                
                // Si quieres que la lista siempre muestre el estado real del disco:
                fileItems = fileItems.map { item in
                    // Si no falló, actualizamos el nombre a lo que ahora tiene en el disco
                    if !failedItems.contains(item) {
                        return FileItem(url: item.url.deletingLastPathComponent().appendingPathComponent(item.newName),
                                        newName: item.newName,
                                        hasAccess: item.hasAccess)
                    }
                    return item
                }
            }
            .disabled(fileItems.isEmpty)
        }
        .padding()
        .onChange(of: findText) { _ in updatePreview() }
        .onChange(of: replaceText) { _ in updatePreview() }
    } // <--- Cierre de body
    
    private func updatePreview() {
            // CORRECCIÓN: Pasamos el arreglo de objetos FileItem, no solo las URLs
            fileItems = RenameEngine.previewRename(files: fileItems, find: findText, replace: replaceText)
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
