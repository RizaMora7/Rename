//
//  RenamePreset.swift
//  Rename
//
//  Created by Raul on 10/10/26.
//

import Foundation

struct RenamePreset: Codable, Identifiable {
    var id = UUID()
    var find: String
    var replace: String
}

class PresetManager: ObservableObject {
    @Published var presets: [RenamePreset] = [] {
        didSet { save() }
    }
    
    // Ruta al archivo
    private var savePath: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let supportFolder = paths[0].appendingPathComponent("RenameApp") // Creamos una subcarpeta propia
        
        // ASEGURAR QUE LA CARPETA EXISTA
        if !FileManager.default.fileExists(atPath: supportFolder.path) {
            try? FileManager.default.createDirectory(at: supportFolder, withIntermediateDirectories: true)
        }
        
        return supportFolder.appendingPathComponent("presets.json")
    }
    
    init() {
        load()
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(presets) {
            try? data.write(to: savePath, options: [.atomic, .completeFileProtection])
        }
    }
    
    func load() {
        // Si el archivo no existe, no hacemos nada (es normal la primera vez)
        guard FileManager.default.fileExists(atPath: savePath.path) else { return }
        
        if let data = try? Data(contentsOf: savePath),
           let decoded = try? JSONDecoder().decode([RenamePreset].self, from: data) {
            presets = decoded
        }
    }
}
