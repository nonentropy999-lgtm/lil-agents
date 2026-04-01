import SwiftUI
import AppKit

@main
struct LilAgentsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: LilAgentsController?
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller = LilAgentsController()
        controller?.start()
        setupMenuBar()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.characters.forEach { $0.session?.terminate() }
    }

    // MARK: - Menu Bar

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuBarIcon") ?? NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "Travis Agents")
        }

        let menu = NSMenu()

        let char1Item = NSMenuItem(title: "Bruce", action: #selector(toggleChar1), keyEquivalent: "1")
        char1Item.state = .on
        menu.addItem(char1Item)

        let char2Item = NSMenuItem(title: "Jazz", action: #selector(toggleChar2), keyEquivalent: "2")
        char2Item.state = .on
        menu.addItem(char2Item)

        menu.addItem(NSMenuItem.separator())

        let soundItem = NSMenuItem(title: "Sounds", action: #selector(toggleSounds(_:)), keyEquivalent: "")
        soundItem.state = .on
        menu.addItem(soundItem)

        // Provider submenu
        let providerItem = NSMenuItem(title: "Provider", action: nil, keyEquivalent: "")
        let providerMenu = NSMenu()
        for (i, provider) in AgentProvider.allCases.enumerated() {
            let item = NSMenuItem(title: provider.displayName, action: #selector(switchProvider(_:)), keyEquivalent: "")
            item.tag = i
            item.state = provider == AgentProvider.current ? .on : .off
            providerMenu.addItem(item)
        }
        providerItem.submenu = providerMenu
        menu.addItem(providerItem)

        let geminiModelItem = NSMenuItem(title: "Gemini Model", action: nil, keyEquivalent: "")
        let geminiModelMenu = NSMenu()
        for (i, model) in GeminiModel.allCases.enumerated() {
            let item = NSMenuItem(title: model.displayName, action: #selector(switchGeminiModel(_:)), keyEquivalent: "")
            item.tag = i
            item.state = model == GeminiModelSettings.current ? .on : .off
            geminiModelMenu.addItem(item)
        }
        geminiModelItem.submenu = geminiModelMenu
        menu.addItem(geminiModelItem)

        // Theme submenu
        let themeItem = NSMenuItem(title: "Style", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu()
        for (i, theme) in PopoverTheme.allThemes.enumerated() {
            let item = NSMenuItem(title: theme.name, action: #selector(switchTheme(_:)), keyEquivalent: "")
            item.tag = i
            item.state = theme.name == PopoverTheme.current.name ? .on : .off
            themeMenu.addItem(item)
        }
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        // Display submenu
        let displayItem = NSMenuItem(title: "Display", action: nil, keyEquivalent: "")
        let displayMenu = NSMenu()
        displayMenu.delegate = self
        let autoItem = NSMenuItem(title: "Auto (Main Display)", action: #selector(switchDisplay(_:)), keyEquivalent: "")
        autoItem.tag = -1
        autoItem.state = .on
        displayMenu.addItem(autoItem)
        displayMenu.addItem(NSMenuItem.separator())
        for (i, screen) in NSScreen.screens.enumerated() {
            let name = screen.localizedName
            let item = NSMenuItem(title: name, action: #selector(switchDisplay(_:)), keyEquivalent: "")
            item.tag = i
            item.state = .off
            displayMenu.addItem(item)
        }
        displayItem.submenu = displayMenu
        menu.addItem(displayItem)

        menu.addItem(NSMenuItem.separator())

        let workspaceItem = NSMenuItem(title: "Workspace: \(WorkspaceSettings.displayName)", action: nil, keyEquivalent: "")
        let workspaceMenu = NSMenu()
        let chooseWorkspaceItem = NSMenuItem(title: "Choose Folder…", action: #selector(chooseWorkspace), keyEquivalent: "")
        chooseWorkspaceItem.target = self
        workspaceMenu.addItem(chooseWorkspaceItem)
        let resetWorkspaceItem = NSMenuItem(title: "Use Home Folder", action: #selector(resetWorkspace), keyEquivalent: "")
        resetWorkspaceItem.target = self
        resetWorkspaceItem.state = WorkspaceSettings.displayName == "Home" ? .on : .off
        workspaceMenu.addItem(resetWorkspaceItem)
        workspaceItem.submenu = workspaceMenu
        menu.addItem(workspaceItem)

        menu.addItem(NSMenuItem.separator())

        let resetPositionsItem = NSMenuItem(title: "Reset Character Positions", action: #selector(resetCharacterPositions), keyEquivalent: "")
        resetPositionsItem.target = self
        menu.addItem(resetPositionsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Menu Actions

    @objc func switchTheme(_ sender: NSMenuItem) {
        let idx = sender.tag
        guard idx < PopoverTheme.allThemes.count else { return }
        PopoverTheme.current = PopoverTheme.allThemes[idx]

        if let themeMenu = sender.menu {
            for item in themeMenu.items {
                item.state = item.tag == idx ? .on : .off
            }
        }

        controller?.characters.forEach { char in
            let wasOpen = char.isIdleForPopover
            if wasOpen { char.popoverWindow?.orderOut(nil) }
            char.popoverWindow = nil
            char.terminalView = nil
            char.thinkingBubbleWindow = nil
            if wasOpen {
                char.createPopoverWindow()
                if let session = char.session, !session.history.isEmpty {
                    char.terminalView?.replayHistory(session.history)
                }
                char.updatePopoverPosition()
                char.popoverWindow?.orderFrontRegardless()
                char.popoverWindow?.makeKey()
                if let terminal = char.terminalView {
                    char.popoverWindow?.makeFirstResponder(terminal.inputField)
                }
            }
        }
    }

    @objc func switchProvider(_ sender: NSMenuItem) {
        let idx = sender.tag
        let allProviders = AgentProvider.allCases
        guard idx < allProviders.count else { return }
        AgentProvider.current = allProviders[idx]

        if let providerMenu = sender.menu {
            for item in providerMenu.items {
                item.state = item.tag == idx ? .on : .off
            }
        }

        // Terminate existing sessions and clear UI so title/placeholder update
        controller?.characters.forEach { char in
            char.session?.terminate()
            char.session = nil
            if char.isIdleForPopover {
                char.closePopover()
            }
            // Always clear popover/bubble so they rebuild with new provider title/placeholder
            char.popoverWindow?.orderOut(nil)
            char.popoverWindow = nil
            char.terminalView = nil
            char.thinkingBubbleWindow?.orderOut(nil)
            char.thinkingBubbleWindow = nil
        }
    }

    @objc func switchGeminiModel(_ sender: NSMenuItem) {
        let idx = sender.tag
        let allModels = GeminiModel.allCases
        guard idx < allModels.count else { return }
        GeminiModelSettings.current = allModels[idx]

        if let modelMenu = sender.menu {
            for item in modelMenu.items {
                item.state = item.tag == idx ? .on : .off
            }
        }

        resetSessionsForWorkspaceChange()
    }

    @objc func switchDisplay(_ sender: NSMenuItem) {
        let idx = sender.tag
        controller?.pinnedScreenIndex = idx

        if let displayMenu = sender.menu {
            for item in displayMenu.items {
                item.state = item.tag == idx ? .on : .off
            }
        }
    }

    @objc func chooseWorkspace(_ sender: NSMenuItem) {
        guard let url = WorkspaceSettings.chooseWorkspace() else { return }
        WorkspaceSettings.currentURL = url
        refreshWorkspaceMenu()
        resetSessionsForWorkspaceChange()
    }

    @objc func resetWorkspace(_ sender: NSMenuItem) {
        WorkspaceSettings.resetToHome()
        refreshWorkspaceMenu()
        resetSessionsForWorkspaceChange()
    }

    @objc func resetCharacterPositions(_ sender: NSMenuItem) {
        controller?.resetCharacterPlacements()
    }

    @objc func toggleChar1(_ sender: NSMenuItem) {
        guard let chars = controller?.characters, chars.count > 0 else { return }
        let char = chars[0]
        if char.isManuallyVisible {
            char.setManuallyVisible(false)
            sender.state = .off
        } else {
            char.setManuallyVisible(true)
            sender.state = .on
        }
    }

    @objc func toggleChar2(_ sender: NSMenuItem) {
        guard let chars = controller?.characters, chars.count > 1 else { return }
        let char = chars[1]
        if char.isManuallyVisible {
            char.setManuallyVisible(false)
            sender.state = .off
        } else {
            char.setManuallyVisible(true)
            sender.state = .on
        }
    }

    @objc func toggleDebug(_ sender: NSMenuItem) {
        guard let debugWin = controller?.debugWindow else { return }
        if debugWin.isVisible {
            debugWin.orderOut(nil)
            sender.state = .off
        } else {
            debugWin.orderFrontRegardless()
            sender.state = .on
        }
    }

    @objc func toggleSounds(_ sender: NSMenuItem) {
        WalkerCharacter.soundsEnabled.toggle()
        sender.state = WalkerCharacter.soundsEnabled ? .on : .off
    }

    private func refreshWorkspaceMenu() {
        guard let menu = statusItem?.menu else { return }
        if let workspaceItem = menu.items.first(where: { $0.title.hasPrefix("Workspace:") }) {
            workspaceItem.title = "Workspace: \(WorkspaceSettings.displayName)"
            if let resetItem = workspaceItem.submenu?.items.last {
                resetItem.state = WorkspaceSettings.displayName == "Home" ? .on : .off
            }
        }
    }

    private func resetSessionsForWorkspaceChange() {
        controller?.characters.forEach { char in
            char.session?.terminate()
            char.session = nil
            if char.isIdleForPopover {
                char.closePopover()
            }
            char.popoverWindow?.orderOut(nil)
            char.popoverWindow = nil
            char.terminalView = nil
            char.thinkingBubbleWindow?.orderOut(nil)
            char.thinkingBubbleWindow = nil
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSMenuDelegate {}
