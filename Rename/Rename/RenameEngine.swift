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

class RenameEngine {
    static func previewRename(files: [FileItem], find: String, replace: String) -> [FileItem] {
        return files.map { item in
            let newName = item.originalName.replacingOccurrences(of: find, with: replace)
            return FileItem(url: item.url, newName: newName, hasAccess: item.hasAccess)
        }
    }
    
    static func applyRenaming(items: [FileItem]) -> [FileItem] {
        let fm = FileManager.default
        var failedItems: [FileItem] = []
        
        for item in items {
            guard item.originalName != item.newName else { continue }
            
            let newURL = item.url.deletingLastPathComponent().appendingPathComponent(item.newName)
            
            do {
                try fm.moveItem(at: item.url, to: newURL)
            } catch {
                print("Error: \(error)")
                failedItems.append(item)
            }
            
            if item.hasAccess {
                item.url.stopAccessingSecurityScopedResource()
            }
        }
        return failedItems
    }
} // <--- Esta es la ÚNICA llave que cierra la clase
