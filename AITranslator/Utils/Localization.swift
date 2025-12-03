import Foundation

enum L10n {
    private static let zhHans: [String: String] = [
        // Tabs
        "settings.tab.general": "通用",
        "settings.tab.api": "API",
        "settings.tab.proxy": "代理",
        "settings.tab.hotkeys": "快捷键",

        // General section
        "settings.general.title": "通用",
        "settings.general.appLanguage": "软件语言",
        "settings.general.appLanguage.followSystem": "跟随系统",
        "settings.general.appLanguage.help": "选择界面语言",
        "settings.general.detectionEngine": "语种检测引擎",
        "settings.general.defaultTargetLanguage": "默认目标语言",
        "settings.general.defaultTargetLanguage.help": "当源语言不是中文时默认翻译到此语言",
        "settings.general.detectionEngine.help": "选择用于自动检测输入语种的引擎",
        "settings.general.historyMaxRecords": "历史记录数",
        "settings.general.historyMaxRecords.help": "设置历史记录最大数量（0=不记录，-1=无限）",

        // API section
        "settings.api.title": "OpenAI 兼容",
        "settings.api.baseURL": "接口地址",
        "settings.api.baseURL.placeholder": "例如：https://api.openai.com/v1/chat/completions",
        "settings.api.baseURL.help": "兼容 OpenAI 的聊天补全接口地址",
        "settings.api.baseURL.invalid": "请输入有效的 URL",
        "settings.api.model": "模型",
        "settings.api.model.placeholder": "例如：gpt-4o-mini / gpt-5-chat",
        "settings.api.model.invalid": "模型不能为空",
        "settings.api.key": "API 密钥",
        "settings.api.key.invalid": "API Key 不能为空",

        // Proxy section
        "settings.proxy.title": "网络代理",
        "settings.proxy.type": "类型",
        "settings.proxy.hostPort": "主机/端口",
        "settings.proxy.host.placeholder": "主机",
        "settings.proxy.port.placeholder": "端口",
        "settings.proxy.invalid": "请填写有效主机，端口范围 1-65535",
        "settings.proxy.credentials": "凭据",
        "settings.proxy.username.placeholder": "用户名（可选）",
        "settings.proxy.password.placeholder": "密码（可选）",
        "settings.proxy.test": "测试代理",
        "settings.proxy.noProxyTargets": "不使用代理的目标",
        "settings.proxy.noProxyTargets.placeholder": "例如：localhost,127.0.0.1,internal.example.com",
        "settings.proxy.noProxyTargets.help": "这些主机名/IP 将绕过代理。用逗号分隔。",

        // Enum values
        "detection.local": "本地算法",
        "detection.google": "Google",
        "detection.baidu": "Baidu",
        "detection.bing": "Bing",
        "proxy.none": "不使用",
        "proxy.http": "HTTP",
        "proxy.socks5": "SOCKS5",

        // Common
        "common.changesNotAutoSaved": "更改不会自动保存，点击\"保存\"后生效。",
        "common.resetDefaults": "恢复默认…",
        "common.import": "导入…",
        "common.export": "导出…",
        "common.save": "保存",
        "common.clear": "清除",
        "common.cancel": "取消",
        "common.reset": "恢复",
        "settings.reset.confirm.title": "确认恢复默认设置？",
        "settings.reset.confirm.message": "这将清除当前更改，并恢复为默认配置。需点击“保存”后生效。",

        // Hotkeys section
        "settings.hotkeys.title": "快捷键",
        "settings.hotkeys.showWindow": "显示/隐藏窗口",
        "settings.hotkeys.toggleMode": "切换模式",
        "settings.hotkeys.quickCopy": "快速复制输出",
        "settings.hotkeys.showWindow.help": "显示/隐藏窗口（全局）：无需切换到应用即可触发",
        "settings.hotkeys.toggleMode.help": "切换翻译/润色/总结（局部）：需在应用前台时生效",
        "settings.hotkeys.quickCopy.help": "复制输出到剪贴板（局部）：需在应用前台时生效",
        "settings.hotkeys.placeholder": "按下组合键…",
        "common.restoreDefault": "恢复默认",
        "settings.hotkeys.sendKey": "发送快捷键",
        "settings.hotkeys.sendKey.enter": "回车发送",
        "settings.hotkeys.sendKey.cmdEnter": "⌘回车发送",
        "settings.hotkeys.sendKey.help": "发送快捷键（局部）：选择回车或⌘回车用于发送",
        "settings.hotkeys.scope.global": "全局",
        "settings.hotkeys.scope.global.help": "全局快捷键：无需切换到应用即可触发",

        // Menus / Commands
        "menu.translation": "翻译",
        "cmd.sendStop": "发送 / 停止",
        "cmd.swapLanguages": "交换语言 (A↔B)",
        "cmd.copyOutput": "复制输出",

        // ContentView toolbar & labels
        "toolbar.pin.on": "取消置顶窗口",
        "toolbar.pin.off": "置顶窗口",
        "toolbar.pin.a11y.on": "取消置顶",
        "toolbar.pin.a11y.off": "置顶",
        "picker.source": "源语言",
        "picker.source.help": "选择源语言",
        "picker.swap.disabled": "润色模式下不可交换",
        "picker.swap.help": "交换源/目标语言（⇧⌘S）",
        "picker.swap.a11y": "交换源语言与目标语言",
        "picker.swap.hint": "仅交换语言，不清空输入与输出",
        "picker.target": "目标语言",
        "picker.target.help": "选择目标语言",
        "picker.mode": "模式",
        "picker.mode.help": "在翻译、润色与总结之间切换",
        "mode.translate": "翻译",
        "mode.polish": "润色",
        "mode.summarize": "总结",

        // ContentView sections
        "section.input": "输入",
        "input.placeholder.enter": "在此输入文本，按 ⏎ 发送",
        "input.placeholder.cmdEnter": "在此输入文本，按 ⌘⏎ 发送",
        "input.clear.help": "清空输入内容",
        "input.clear.a11y": "清空输入",
        "input.clear.hint": "清除当前输入文本",
        "section.output": "输出",
        "output.placeholder": "结果将显示在此",
        "hint.placeholder.enter": "提示：按 ⏎ 发送，Esc 停止",
        "hint.placeholder.cmdEnter": "提示：按 ⌘⏎ 发送，Esc 停止",
        "output.copy.help": "复制输出到剪贴板（⌘S）",
        "output.copy.a11y": "复制全部输出",
        "output.copy.hint": "将结果复制到剪贴板",

        // Bottom bar
        "streaming": "生成中…",
        "streaming.a11y": "正在生成",
        "streaming.hint": "可点击停止以中断生成",
        "completed": "已完成",
        "completed.a11y": "生成完成",
        "completed.hint": "已生成结果",
        "failed": "生成失败",
        "btn.stop": "停止",
        "btn.send": "发送",
        "btn.stop.help": "停止生成（Esc）",
        "btn.stop.a11y": "停止生成",
        "btn.stop.hint": "中断当前请求",
        "btn.send.help": "发送请求（⌘⏎）",
        "btn.send.a11y": "发送请求",
        "btn.send.hint": "开始翻译、润色或总结",

        // Toasts
        "toast.pinned": "已置顶窗口",
        "toast.unpinned": "已取消置顶",
        "toast.export.success": "配置已导出",
        "toast.export.failure.prefix": "导出失败：",
        "toast.import.failure.prefix": "导入失败：",
        "toast.copied": "已复制到剪贴板",

        // History Window
        "toolbar.history": "历史记录",
        "toolbar.history.a11y": "查看历史记录",
        "history.search.placeholder": "搜索历史记录...",
        "history.filter.all": "全部",
        "history.button.export": "导出历史记录",
        "history.button.import": "导入历史记录",
        "history.button.clear": "清空所有历史记录",
        "history.empty.noRecords": "暂无历史记录",
        "history.empty.noResults": "没有找到匹配的记录",
        "history.detail.input": "输入",
        "history.detail.output": "输出",
        "history.detail.copyInput": "复制输入",
        "history.detail.copyOutput": "复制输出",
        "history.detail.delete": "删除",
        "history.detail.selectPrompt": "选择一条记录查看详情",
        "history.confirm.deleteTitle": "确认删除",
        "history.confirm.deleteMessage": "确定要删除这条历史记录吗？",
        "history.confirm.clearTitle": "确认清空",
        "history.confirm.clearMessage": "确定要清空所有历史记录吗？此操作不可恢复。",
        "history.confirm.cancel": "取消",
        "history.confirm.ok": "确定",
        "history.import.title": "导入历史记录",
        "history.import.optionsTitle": "导入选项",
        "history.import.optionsMessage": "选择如何导入历史记录：\n• 合并：保留现有记录，添加新记录\n• 替换：删除现有记录，使用导入的记录",
        "history.import.merge": "合并",
        "history.import.replace": "替换",
        "history.import.success.merge": "导入成功：添加 %d 条新记录",
        "history.import.success.replace": "导入成功：%d 条记录",
        "history.import.failure": "导入失败：%@",
        "history.export.title": "导出历史记录",
        "history.export.success": "导出成功：%d 条记录",
        "history.export.failure": "导出失败：%@",
        "history.toast.copied": "已复制到剪贴板",
        "history.contextMenu.copyInput": "复制输入",
        "history.contextMenu.copyOutput": "复制输出",
        "history.contextMenu.delete": "删除",
        "history.date.today": "今天",
        "history.date.yesterday": "昨天",
        "history.date.thisWeek": "本周",
        "history.date.thisMonth": "本月",

        // History Settings (simplified)
        "settings.history.disabled": "不记录",
        "settings.history.unlimited": "无限制"
    ]

    private static let en: [String: String] = [
        // Tabs
        "settings.tab.general": "General",
        "settings.tab.api": "API",
        "settings.tab.proxy": "Proxy",
        "settings.tab.hotkeys": "Hotkeys",

        // General section
        "settings.general.title": "General",
        "settings.general.appLanguage": "App Language",
        "settings.general.appLanguage.followSystem": "Follow System",
        "settings.general.appLanguage.help": "Choose the app interface language",
        "settings.general.detectionEngine": "Detection Engine",
        "settings.general.defaultTargetLanguage": "Default Target Language",
        "settings.general.defaultTargetLanguage.help": "When source is not Chinese, translate to this language",
        "settings.general.detectionEngine.help": "Choose engine for automatic language detection",
        "settings.general.historyMaxRecords": "History Records",
        "settings.general.historyMaxRecords.help": "Set maximum history records (0=disabled, -1=unlimited)",

        // API section
        "settings.api.title": "OpenAI Compatible",
        "settings.api.baseURL": "Base URL",
        "settings.api.baseURL.placeholder": "e.g. https://api.openai.com/v1/chat/completions",
        "settings.api.baseURL.help": "OpenAI-compatible chat completions endpoint",
        "settings.api.baseURL.invalid": "Please enter a valid URL",
        "settings.api.model": "Model",
        "settings.api.model.placeholder": "e.g. gpt-4o-mini / gpt-5-chat",
        "settings.api.model.invalid": "Model cannot be empty",
        "settings.api.key": "API Key",
        "settings.api.key.invalid": "API Key is required",

        // Proxy section
        "settings.proxy.title": "Network Proxy",
        "settings.proxy.type": "Type",
        "settings.proxy.hostPort": "Host/Port",
        "settings.proxy.host.placeholder": "Host",
        "settings.proxy.port.placeholder": "Port",
        "settings.proxy.invalid": "Enter a valid host, port range 1-65535",
        "settings.proxy.credentials": "Credentials",
        "settings.proxy.username.placeholder": "Username (optional)",
        "settings.proxy.password.placeholder": "Password (optional)",
        "settings.proxy.test": "Test Proxy",
        "settings.proxy.noProxyTargets": "No Proxy Targets",
        "settings.proxy.noProxyTargets.placeholder": "e.g. localhost,127.0.0.1,internal.example.com",
        "settings.proxy.noProxyTargets.help": "These hostnames/IPs will bypass the proxy. Separate with commas.",

        // Enum values
        "detection.local": "Local",
        "detection.google": "Google",
        "detection.baidu": "Baidu",
        "detection.bing": "Bing",
        "proxy.none": "Do not use",
        "proxy.http": "HTTP",
        "proxy.socks5": "SOCKS5",

        // Common
        "common.changesNotAutoSaved": "Changes are not auto-saved. Click Save to apply.",
        "common.resetDefaults": "Reset to Defaults…",
        "common.import": "Import…",
        "common.export": "Export…",
        "common.save": "Save",
        "common.clear": "Clear",
        "common.cancel": "Cancel",
        "common.reset": "Reset",
        "settings.reset.confirm.title": "Reset to defaults?",
        "settings.reset.confirm.message": "This clears current changes and restores defaults. Click Save to apply.",

        // Hotkeys section
        "settings.hotkeys.title": "Hotkeys",
        "settings.hotkeys.showWindow": "Show/Hide Window",
        "settings.hotkeys.toggleMode": "Toggle Mode",
        "settings.hotkeys.quickCopy": "Quick Copy Output",
        "settings.hotkeys.showWindow.help": "Show/Hide window (Global): works even when the app is not focused",
        "settings.hotkeys.toggleMode.help": "Toggle Translate/Polish/Summarize (Local): active only when app is focused",
        "settings.hotkeys.quickCopy.help": "Copy output to clipboard (Local): active only when app is focused",
        "settings.hotkeys.placeholder": "Press shortcut…",
        "common.restoreDefault": "Restore Default",
        "settings.hotkeys.sendKey": "Send Key",
        "settings.hotkeys.sendKey.enter": "Enter to Send",
        "settings.hotkeys.sendKey.cmdEnter": "Cmd+Enter to Send",
        "settings.hotkeys.sendKey.help": "Send shortcut (Local): choose Enter or Cmd+Enter to send",
        "settings.hotkeys.scope.global": "Global",
        "settings.hotkeys.scope.global.help": "Global shortcut: works even when the app is not focused",

        // Menus / Commands
        "menu.translation": "Translation",
        "cmd.sendStop": "Send / Stop",
        "cmd.swapLanguages": "Swap Languages (A↔B)",
        "cmd.copyOutput": "Copy Output",

        // ContentView toolbar & labels
        "toolbar.pin.on": "Unpin Window",
        "toolbar.pin.off": "Pin Window",
        "toolbar.pin.a11y.on": "Unpin",
        "toolbar.pin.a11y.off": "Pin",
        "picker.source": "Source",
        "picker.source.help": "Choose source language",
        "picker.swap.disabled": "Swap unavailable in Polish mode",
        "picker.swap.help": "Swap source/target (⇧⌘S)",
        "picker.swap.a11y": "Swap source and target languages",
        "picker.swap.hint": "Swap languages only; keep input/output",
        "picker.target": "Target",
        "picker.target.help": "Choose target language",
        "picker.mode": "Mode",
        "picker.mode.help": "Switch between Translate, Polish, and Summarize",
        "mode.translate": "Translate",
        "mode.polish": "Polish",
        "mode.summarize": "Summarize",

        // ContentView sections
        "section.input": "Input",
        "input.placeholder.enter": "Type here, press ⏎ to send",
        "input.placeholder.cmdEnter": "Type here, press ⌘⏎ to send",
        "input.clear.help": "Clear input",
        "input.clear.a11y": "Clear",
        "input.clear.hint": "Clear current input text",
        "section.output": "Output",
        "output.placeholder": "Result will appear here",
        "hint.placeholder.enter": "Tip: Press ⏎ to send, Esc to stop",
        "hint.placeholder.cmdEnter": "Tip: Press ⌘⏎ to send, Esc to stop",
        "output.copy.help": "Copy output to clipboard (⌘S)",
        "output.copy.a11y": "Copy all output",
        "output.copy.hint": "Copy the result to clipboard",

        // Bottom bar
        "streaming": "Generating…",
        "streaming.a11y": "Generating",
        "streaming.hint": "Click Stop to interrupt",
        "completed": "Completed",
        "completed.a11y": "Generation completed",
        "completed.hint": "Result generated",
        "failed": "Failed",
        "btn.stop": "Stop",
        "btn.send": "Send",
        "btn.stop.help": "Stop generation (Esc)",
        "btn.stop.a11y": "Stop generation",
        "btn.stop.hint": "Interrupt current request",
        "btn.send.help": "Send request (⌘⏎)",
        "btn.send.a11y": "Send request",
        "btn.send.hint": "Start translate, polish, or summarize",

        // Toasts
        "toast.pinned": "Window pinned",
        "toast.unpinned": "Window unpinned",
        "toast.export.success": "Preferences exported",
        "toast.export.failure.prefix": "Export failed: ",
        "toast.import.failure.prefix": "Import failed: ",
        "toast.copied": "Copied to clipboard",

        // History Window
        "toolbar.history": "History",
        "toolbar.history.a11y": "View history",
        "history.search.placeholder": "Search history...",
        "history.filter.all": "All",
        "history.button.export": "Export History",
        "history.button.import": "Import History",
        "history.button.clear": "Clear all history",
        "history.empty.noRecords": "No History",
        "history.empty.noResults": "No Results",
        "history.detail.input": "Input",
        "history.detail.output": "Output",
        "history.detail.copyInput": "Copy Input",
        "history.detail.copyOutput": "Copy Output",
        "history.detail.delete": "Delete",
        "history.detail.selectPrompt": "Select a record to view details",
        "history.confirm.deleteTitle": "Confirm Delete",
        "history.confirm.deleteMessage": "Are you sure you want to delete this history record?",
        "history.confirm.clearTitle": "Confirm Clear",
        "history.confirm.clearMessage": "Are you sure you want to clear all history? This action cannot be undone.",
        "history.confirm.cancel": "Cancel",
        "history.confirm.ok": "OK",
        "history.import.title": "Import History",
        "history.import.optionsTitle": "Import Options",
        "history.import.optionsMessage": "Choose how to import history:\n• Merge: Keep existing records and add new ones\n• Replace: Delete existing records and use imported ones",
        "history.import.merge": "Merge",
        "history.import.replace": "Replace",
        "history.import.success.merge": "Imported: %d new records added",
        "history.import.success.replace": "Imported: %d records",
        "history.import.failure": "Import failed: %@",
        "history.export.title": "Export History",
        "history.export.success": "Exported: %d records",
        "history.export.failure": "Export failed: %@",
        "history.toast.copied": "Copied to clipboard",
        "history.contextMenu.copyInput": "Copy Input",
        "history.contextMenu.copyOutput": "Copy Output",
        "history.contextMenu.delete": "Delete",
        "history.date.today": "Today",
        "history.date.yesterday": "Yesterday",
        "history.date.thisWeek": "This Week",
        "history.date.thisMonth": "This Month",

        // History Settings (simplified)
        "settings.history.disabled": "Disabled",
        "settings.history.unlimited": "Unlimited"
    ]

    static func tr(_ key: String, lang: AppLanguage) -> String {
        let resolvedLang: AppLanguage = {
            if case .system = lang {
                if let code = Locale.autoupdatingCurrent.language.languageCode?.identifier,
                    code.lowercased().hasPrefix("zh") {
                    return .zhHans
                } else {
                    return .en
                }
            }
            return lang
        }()

        switch resolvedLang {
        case .zhHans:
            return zhHans[key] ?? key
        case .en:
            return en[key] ?? key
        case .system:
            // unreachable due to resolution above
            return key
        }
    }

    static func languageDisplayName(_ option: AppLanguage, uiLang: AppLanguage) -> String {
        switch option {
        case .system:
            return tr("settings.general.appLanguage.followSystem", lang: uiLang)
        case .zhHans:
            return uiLang == .en ? "Simplified Chinese" : "简体中文"
        case .en:
            return uiLang == .en ? "English" : "英语"
        }
    }
}
