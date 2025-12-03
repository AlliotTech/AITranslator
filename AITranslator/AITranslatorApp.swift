import SwiftUI

@main
struct AITranslatorApp: App {
    @StateObject private var viewModel: AppViewModel = AppViewModel()

    var body: some Scene {
        let locale: Locale? = {
            if let id = viewModel.preferences.appLanguage.localeIdentifier {
                return Locale(identifier: id)
            }
            return nil
        }()
        WindowGroup {
            ContentView(viewModel: viewModel)
                .environment(\.locale, locale ?? .autoupdatingCurrent)
        }
        .defaultSize(width: 800, height: 560)

        // 使用系统原生的 Settings Scene，提供最佳体验
        Settings {
            SettingsView(viewModel: viewModel)
                .environment(\.locale, locale ?? .autoupdatingCurrent)
                .frame(width: 520, height: 400)
        }
        .defaultSize(width: 520, height: 400)
        .windowResizability(.contentSize)

        .commands {
            CommandMenu(L10n.tr("menu.translation", lang: viewModel.preferences.appLanguage)) {
                Button(L10n.tr("cmd.sendStop", lang: viewModel.preferences.appLanguage)) {
                    if viewModel.isStreaming {
                        viewModel.stopStreaming()
                    } else {
                        viewModel.send()
                    }
                }
                .keyboardShortcut(.return, modifiers: viewModel.preferences.sendKey == .enter ? [] : [.command])

                Button(L10n.tr("cmd.swapLanguages", lang: viewModel.preferences.appLanguage)) {
                    viewModel.swapLanguages()
                }
                .keyboardShortcut("S", modifiers: [.command, .shift])

                // 移除硬编码的 cmd+s 快捷键，改为由用户在设置中自定义
                // 快捷键由 HotkeyManager 全局管理，避免冲突
                Button(L10n.tr("cmd.copyOutput", lang: viewModel.preferences.appLanguage)) {
                    viewModel.copyOutputToClipboard()
                }
                // 不再为复制输出设置硬编码的快捷键，使用用户在设置中配置的全局快捷键
            }
        }
    }
}
