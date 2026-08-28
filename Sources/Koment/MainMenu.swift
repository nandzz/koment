import AppKit

struct MainMenu {
    func install(in application: NSApplication) {
        let menu = NSMenu()
        menu.addItem(appMenu(application))
        menu.addItem(editMenu())
        let window = windowMenu()
        menu.addItem(window)
        application.mainMenu = menu
        application.windowsMenu = window.submenu
    }

    private func appMenu(_ application: NSApplication) -> NSMenuItem {
        let name = ProcessInfo.processInfo.processName
        let submenu = NSMenu(title: name)
        submenu.addItem(item("About \(name)", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), ""))
        submenu.addItem(.separator())
        submenu.addItem(item("Hide \(name)", #selector(NSApplication.hide(_:)), "h"))

        let hideOthers = item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        submenu.addItem(hideOthers)

        submenu.addItem(item("Show All", #selector(NSApplication.unhideAllApplications(_:)), ""))
        submenu.addItem(.separator())
        submenu.addItem(item("Quit \(name)", #selector(NSApplication.terminate(_:)), "q"))

        let root = NSMenuItem()
        root.submenu = submenu
        return root
    }

    private func editMenu() -> NSMenuItem {
        let submenu = NSMenu(title: "Edit")
        submenu.addItem(item("Undo", Selector(("undo:")), "z"))

        let redo = item("Redo", Selector(("redo:")), "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        submenu.addItem(redo)

        submenu.addItem(.separator())
        submenu.addItem(item("Cut", #selector(NSText.cut(_:)), "x"))
        submenu.addItem(item("Copy", #selector(NSText.copy(_:)), "c"))
        submenu.addItem(item("Paste", #selector(NSText.paste(_:)), "v"))

        let pastePlain = item("Paste and Match Style", #selector(NSTextView.pasteAsPlainText(_:)), "v")
        pastePlain.keyEquivalentModifierMask = [.command, .option, .shift]
        submenu.addItem(pastePlain)

        submenu.addItem(item("Delete", #selector(NSText.delete(_:)), ""))
        submenu.addItem(item("Select All", #selector(NSText.selectAll(_:)), "a"))
        submenu.addItem(.separator())
        submenu.addItem(findMenu())

        let root = NSMenuItem()
        root.title = "Edit"
        root.submenu = submenu
        return root
    }

    private func findMenu() -> NSMenuItem {
        let submenu = NSMenu(title: "Find")

        let find = item("Find…", #selector(NSTextView.performFindPanelAction(_:)), "f")
        find.tag = NSTextFinder.Action.showFindInterface.rawValue
        submenu.addItem(find)

        let next = item("Find Next", #selector(NSTextView.performFindPanelAction(_:)), "g")
        next.tag = NSTextFinder.Action.nextMatch.rawValue
        submenu.addItem(next)

        let previous = item("Find Previous", #selector(NSTextView.performFindPanelAction(_:)), "g")
        previous.tag = NSTextFinder.Action.previousMatch.rawValue
        previous.keyEquivalentModifierMask = [.command, .shift]
        submenu.addItem(previous)

        let root = NSMenuItem()
        root.title = "Find"
        root.submenu = submenu
        return root
    }

    private func windowMenu() -> NSMenuItem {
        let submenu = NSMenu(title: "Window")
        submenu.addItem(item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"))
        submenu.addItem(item("Close", #selector(NSWindow.performClose(_:)), "w"))

        let root = NSMenuItem()
        root.title = "Window"
        root.submenu = submenu
        return root
    }

    private func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        NSMenuItem(title: title, action: action, keyEquivalent: key)
    }
}
