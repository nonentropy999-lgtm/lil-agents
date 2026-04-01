import AppKit
import Foundation

enum WorkspaceSettings {
    private static let defaultsKey = "workspacePath"

    static var currentURL: URL {
        get {
            if let path = UserDefaults.standard.string(forKey: defaultsKey),
               !path.isEmpty {
                let url = URL(fileURLWithPath: path, isDirectory: true)
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    return url
                }
            }
            return FileManager.default.homeDirectoryForCurrentUser
        }
        set {
            UserDefaults.standard.set(newValue.path, forKey: defaultsKey)
        }
    }

    static var displayName: String {
        let url = currentURL
        if url.path == FileManager.default.homeDirectoryForCurrentUser.path {
            return "Home"
        }
        return url.lastPathComponent
    }

    static func chooseWorkspace() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose Workspace Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = currentURL
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func resetToHome() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
