import AppKit
import Sparkle

/// Keep the updater alive; local builds without a signing key cannot install updates.
final class AppUpdates: NSObject, NSMenuItemValidation {
    private var controller: SPUStandardUpdaterController?

    override init() {
        super.init()
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32 else { return }
        controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    @objc func checkForUpdates(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        guard let controller else {
            let alert = NSAlert()
            alert.messageText = L10n.text("Обновления ещё не настроены")
            alert.informativeText = L10n.text("В этой сборке нет ключа обновлений. Пока обновляйте приложение вручную по README.")
            alert.addButton(withTitle: L10n.text("Понятно"))
            alert.runModal()
            return
        }
        controller.checkForUpdates(sender)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        controller?.updater.canCheckForUpdates ?? true
    }
}
