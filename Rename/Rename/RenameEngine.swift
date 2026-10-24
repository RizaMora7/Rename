//
//  RenameEngine.swift
//  Rename
//
//  Created by Raul on 10/10/26.
//

import Foundation

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    var newName: String
    var hasAccess: Bool = false

    var originalName: String { url.lastPathComponent }
}

/// Un problema encontrado al aplicar un lote (colisión o fallo del sistema de archivos).
struct RenameError: Identifiable {
    let id = UUID()
    let fileName: String
    let reason: String
}

/// Resultado de aplicar un lote de renombrados.
struct RenameOutcome {
    var renamed: [(from: URL, to: URL)] = []   // pares aplicados con éxito (para deshacer)
    var skipped: Int = 0                       // ítems cuyo nombre no cambia
    var errors: [RenameError] = []             // colisiones + fallos
}

enum RenameEngine {

    /// Calcula el nombre nuevo aplicando buscar/reemplazar.
    /// Si `protectExtension` es true, la extensión del archivo no se modifica.
    static func renamedName(from original: String,
                            find: String,
                            replace: String,
                            protectExtension: Bool) -> String {
        guard !find.isEmpty else { return original }

        if protectExtension {
            let ext = (original as NSString).pathExtension
            if ext.isEmpty {
                // Sin extensión: se reemplaza en todo el nombre.
                return original.replacingOccurrences(of: find, with: replace)
            }
            let base = (original as NSString).deletingPathExtension
            let newBase = base.replacingOccurrences(of: find, with: replace)
            return newBase + "." + ext
        } else {
            return original.replacingOccurrences(of: find, with: replace)
        }
    }

    /// Vista previa: recalcula `newName` de cada archivo sin tocar el disco.
    static func previewRename(files: [FileItem],
                              find: String,
                              replace: String,
                              protectExtension: Bool) -> [FileItem] {
        return files.map { item in
            let newName = renamedName(from: item.originalName,
                                      find: find,
                                      replace: replace,
                                      protectExtension: protectExtension)
            return FileItem(url: item.url, newName: newName, hasAccess: item.hasAccess)
        }
    }

    /// Aplica los renombrados de forma segura. Detecta colisiones tanto contra el
    /// disco como dentro del propio lote antes de mover, y devuelve un resultado que
    /// permite mostrar los errores y deshacer lo aplicado.
    static func applyRenaming(items: [FileItem], protectExtension: Bool) -> RenameOutcome {
        let fm = FileManager.default
        var outcome = RenameOutcome()

        struct Plan { let item: FileItem; let target: URL }
        var plans: [Plan] = []
        var seenTargets: Set<String> = []

        // 1) Planificar destinos: separar "sin cambio" y detectar duplicados internos.
        for item in items {
            if item.originalName == item.newName {
                outcome.skipped += 1
                continue
            }
            let target = item.url.deletingLastPathComponent().appendingPathComponent(item.newName)
            let key = target.path.lowercased()
            if seenTargets.contains(key) {
                outcome.errors.append(RenameError(fileName: item.originalName,
                                                  reason: "Conflicto: dos archivos apuntan al mismo nombre destino"))
                continue
            }
            seenTargets.insert(key)
            plans.append(Plan(item: item, target: target))
        }

        // 2) Ejecutar, verificando contra el disco antes de mover.
        for plan in plans {
            let item = plan.item
            let target = plan.target
            let sameFile = target.path.lowercased() == item.url.path.lowercased()

            if !sameFile && fm.fileExists(atPath: target.path) {
                outcome.errors.append(RenameError(fileName: item.originalName,
                                                  reason: "Ya existe un archivo con el nombre destino"))
                continue
            }

            do {
                try fm.moveItem(at: item.url, to: target)
                outcome.renamed.append((from: item.url, to: target))
            } catch {
                outcome.errors.append(RenameError(fileName: item.originalName,
                                                  reason: error.localizedDescription))
            }

            if item.hasAccess {
                item.url.stopAccessingSecurityScopedResource()
            }
        }
        return outcome
    }

    /// Deshace un lote previamente renombrado, en orden inverso. Devuelve los problemas
    /// encontrados (p. ej. que el nombre original haya vuelto a quedar ocupado).
    static func undo(renamed: [(from: URL, to: URL)]) -> [RenameError] {
        let fm = FileManager.default
        var errors: [RenameError] = []

        for pair in renamed.reversed() {
            let sameFile = pair.from.path.lowercased() == pair.to.path.lowercased()
            if !sameFile && fm.fileExists(atPath: pair.from.path) {
                errors.append(RenameError(fileName: pair.to.lastPathComponent,
                                          reason: "El nombre original ya está en uso; no se pudo deshacer"))
                continue
            }
            do {
                try fm.moveItem(at: pair.to, to: pair.from)
            } catch {
                errors.append(RenameError(fileName: pair.to.lastPathComponent,
                                          reason: error.localizedDescription))
            }
        }
        return errors
    }
}
