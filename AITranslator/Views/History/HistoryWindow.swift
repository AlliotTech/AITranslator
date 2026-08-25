import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// 历史记录主窗口
/// 包含搜索、筛选、列表和详情面板
struct HistoryWindow: View {
    @ObservedObject var historyManager: HistoryManager
    let preferences: Preferences

    @Environment(\.l10n)
    private var l10n

    @State private var searchText: String = ""
    @State private var selectedMode: AppMode?
    @State private var selectedRecord: HistoryRecord?
    @State private var showDeleteConfirm = false
    @State private var showClearAllConfirm = false
    @State private var showImportOptions = false
    @State private var toastMessage: String?

    /// 当前过滤后的记录列表
    private var filteredRecords: [HistoryRecord] {
        historyManager.searchAndFilter(
            query: searchText,
            mode: selectedMode
        )
    }

    /// 按日期分组的记录
    private var groupedRecords: [(String, [HistoryRecord])] {
        historyManager.groupByDate(filteredRecords, appLanguage: preferences.appLanguage)
    }

    var body: some View {
        HSplitView {
            // 左侧：列表面板
            listPanel
                .frame(minWidth: 300, maxWidth: 400)

            // 右侧：详情面板
            if let record = selectedRecord {
                detailPanel(record)
                    .frame(minWidth: 400)
            } else {
                emptyDetailPanel
                    .frame(minWidth: 400)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .overlay(alignment: .bottom) {
            if let message = toastMessage {
                HistoryToastView(message: message)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 12)
            }
        }
        .animation(Animations.spring, value: toastMessage)
        .alert(
            l10n("history.import.optionsTitle"),
            isPresented: $showImportOptions
        ) {
            Button(l10n("history.confirm.cancel"), role: .cancel) {}
            Button(l10n("history.import.merge")) {
                performImport(merge: true)
            }
            Button(l10n("history.import.replace"), role: .destructive) {
                performImport(merge: false)
            }
        } message: {
            Text(l10n("history.import.optionsMessage"))
        }
    }

    // MARK: - List Panel

    private var listPanel: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbarView
                .padding(8)  // 12 → 8
                .background(AppColors.windowBackground)

            Divider()

            // 记录列表
            if filteredRecords.isEmpty {
                emptyStateView
            } else {
                recordsListView
            }
        }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        VStack(spacing: 6) {  // 8 → 6
            // 搜索框
            HStack(spacing: 6) {  // 8 → 6
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))  // 14 → 13

                TextField(
                    l10n("history.search.placeholder"),
                    text: $searchText
                )
                .textFieldStyle(.plain)
                .font(.system(size: 12))  // 13 → 12

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))  // 14 → 13
                    }
                    .buttonStyle(.plain)
                    .buttonCursor()
                }
            }
            .padding(6)  // 8 → 6
            .background(AppColors.inputBackground)
            .cornerRadius(6)

            // 筛选和操作按钮
            HStack(spacing: 6) {  // 8 → 6
                // 模式筛选
                Picker("", selection: $selectedMode) {
                    Text(l10n("history.filter.all"))
                        .tag(nil as AppMode?)
                    ForEach(AppMode.allCases) { mode in
                        Text(l10n.modeName(mode)).tag(mode as AppMode?)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)

                Spacer()

                // 导出按钮
                Button(action: { exportHistory() }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13))
                }
                .buttonCursor()
                .help(l10n("history.button.export"))
                .disabled(historyManager.records.isEmpty)

                // 导入按钮
                Button(action: { importHistory() }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 13))
                }
                .buttonCursor()
                .help(l10n("history.button.import"))

                // 清空按钮
                Button(action: { showClearAllConfirm = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))  // 14 → 13
                }
                .buttonCursor()
                .help(l10n("history.button.clear"))
                .disabled(historyManager.records.isEmpty)
            }
        }
    }

    // MARK: - Records List

    private var recordsListView: some View {
        ScrollViewReader { _ in
            List(selection: $selectedRecord) {
                ForEach(groupedRecords, id: \.0) { groupName, records in
                    Section(header: Text(groupName).font(.headline).foregroundColor(.secondary)) {
                        ForEach(records) { record in
                            HistoryRecordRow(record: record, preferences: preferences)
                                .tag(record)
                                .contextMenu {
                                    Button(l10n("history.contextMenu.copyInput")) {
                                        copyToClipboard(record.input)
                                    }
                                    Button(l10n("history.contextMenu.copyOutput")) {
                                        copyToClipboard(record.output)
                                    }
                                    Divider()
                                    Button(l10n("history.contextMenu.delete"), role: .destructive) {
                                        historyManager.deleteRecord(id: record.id)
                                        if selectedRecord?.id == record.id {
                                            selectedRecord = nil
                                        }
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {  // 16 → 12
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))  // 64 → 48
                .foregroundColor(.secondary)

            Text(searchText.isEmpty ?
                l10n("history.empty.noRecords") :
                l10n("history.empty.noResults")
            )
            .font(.headline)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Detail Panel

    private func detailPanel(_ record: HistoryRecord) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {  // 16 → 12
                // 元数据合并为一行（紧凑布局）
                HStack(spacing: 8) {
                    Label(l10n.modeName(record.mode), systemImage: modeIcon(record.mode))
                        .font(.subheadline)
                        .foregroundColor(modeColor(record.mode))

                    Text("•")
                        .foregroundColor(.secondary)

                    Text("\(historyProviderName(record.provider)) · \(record.service)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text("\(languageName(record.sourceLang)) → \(languageName(record.targetLang))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    let locale = Locale(identifier: preferences.appLanguage.localeIdentifier ?? "en")
                    Text(record.formattedTimestamp(locale: locale))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // 输入
                VStack(alignment: .leading, spacing: 6) {  // 8 → 6
                    Text(l10n("history.detail.input"))
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(record.input)
                        .textSelection(.enabled)
                        .font(.body)
                        .padding(8)  // 12 → 8
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.inputBackground)
                        .cornerRadius(6)  // 8 → 6
                }

                // 输出
                VStack(alignment: .leading, spacing: 6) {  // 8 → 6
                    Text(l10n("history.detail.output"))
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(record.output)
                        .textSelection(.enabled)
                        .font(.body)
                        .padding(8)  // 12 → 8
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.outputBackground)
                        .cornerRadius(6)  // 8 → 6
                }

                // 操作按钮
                HStack(spacing: 8) {  // 12 → 8
                    Button(l10n("history.detail.copyInput")) {
                        copyToClipboard(record.input)
                    }
                    .buttonCursor()

                    Button(l10n("history.detail.copyOutput")) {
                        copyToClipboard(record.output)
                    }
                    .buttonCursor()

                    Spacer()

                    Button(role: .destructive, action: {
                        showDeleteConfirm = true
                    }) {
                        Label(
                            l10n("history.detail.delete"),
                            systemImage: "trash"
                        )
                    }
                    .buttonCursor()
                }
                .padding(.top, 6)  // 8 → 6
            }
            .padding(12)  // 16 → 12
        }
        .alert(
            l10n("history.confirm.deleteTitle"),
            isPresented: $showDeleteConfirm
        ) {
            Button(l10n("history.confirm.cancel"), role: .cancel) {}
            Button(l10n("history.detail.delete"), role: .destructive) {
                historyManager.deleteRecord(id: record.id)
                selectedRecord = nil
            }
        } message: {
            Text(l10n("history.confirm.deleteMessage"))
        }
        .alert(
            l10n("history.confirm.clearTitle"),
            isPresented: $showClearAllConfirm
        ) {
            Button(l10n("history.confirm.cancel"), role: .cancel) {}
            Button(l10n("history.button.clear"), role: .destructive) {
                historyManager.clearAll()
                selectedRecord = nil
            }
        } message: {
            Text(l10n("history.confirm.clearMessage"))
        }
    }

    private var emptyDetailPanel: some View {
        VStack(spacing: 12) {  // 16 → 12
            Image(systemName: "doc.text")
                .font(.system(size: 36))  // 48 → 36
                .foregroundColor(.secondary)

            Text(l10n("history.detail.selectPrompt"))
                .font(.subheadline)  // headline → subheadline
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Import/Export Methods

    /// 导出历史记录
    private func exportHistory() {
        let savePanel = NSSavePanel()
        savePanel.title = l10n("history.export.title")
        savePanel.nameFieldStringValue = "history_\(Date().timeIntervalSince1970).json"
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }

            do {
                try historyManager.exportToJSON(url: url)
                let message = l10n(
                    "history.export.success",
                    historyManager.records.count
                )
                showToast(message)
            } catch {
                let message = l10n(
                    "history.export.failure",
                    error.localizedDescription
                )
                showToast(message)
            }
        }
    }

    /// 导入历史记录（显示选项对话框）
    private func importHistory() {
        let openPanel = NSOpenPanel()
        openPanel.title = l10n("history.import.title")
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false

        openPanel.begin { response in
            guard response == .OK, let url = openPanel.url else { return }

            // 显示导入选项对话框
            showImportOptions = true

            // 保存选中的URL供后续使用
            UserDefaults.standard.set(url.path, forKey: "PendingImportURL")
        }
    }

    /// 执行导入操作
    /// - Parameter merge: true=合并，false=替换
    private func performImport(merge: Bool) {
        guard let urlPath = UserDefaults.standard.string(forKey: "PendingImportURL") else { return }
        let url = URL(fileURLWithPath: urlPath)

        // 清理临时数据
        UserDefaults.standard.removeObject(forKey: "PendingImportURL")

        do {
            let oldCount = historyManager.records.count
            try historyManager.importFromJSON(url: url, merge: merge)
            let newCount = historyManager.records.count

            let message: String
            if merge {
                let added = newCount - oldCount
                message = l10n(
                    "history.import.success.merge",
                    added
                )
            } else {
                message = l10n(
                    "history.import.success.replace",
                    newCount
                )
            }
            showToast(message)

            // 清除当前选中的记录
            selectedRecord = nil
        } catch {
            let message = l10n(
                "history.import.failure",
                error.localizedDescription
            )
            showToast(message)
        }
    }

    // MARK: - Helper Methods

    private func modeIcon(_ mode: AppMode) -> String {
        switch mode {
        case .translate: return "arrow.left.arrow.right"
        case .polish: return "sparkles"
        case .summarize: return "doc.text"
        }
    }

    private func modeColor(_ mode: AppMode) -> Color {
        switch mode {
        case .translate: return .blue
        case .polish: return .purple
        case .summarize: return .green
        }
    }

    private func languageName(_ code: String) -> String {
        LanguageUtils.displayName(for: code)
    }

    private func historyProviderName(_ provider: HistoryProvider) -> String {
        switch provider {
        case .openAICompatible:
            return l10n("history.provider.openAI")
        case .deepLCompatible:
            return l10n("history.provider.deepL")
        }
    }

    private func copyToClipboard(_ text: String) {
        Clipboard.copy(text)

        // 显示复制成功提示
        let message = l10n("history.toast.copied")
        showToast(message)
    }

    private func showToast(_ message: String) {
        toastMessage = message

        // 2秒后自动清除
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }
}

// MARK: - History Toast View

/// 历史记录窗口的 Toast 提示视图
private struct HistoryToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(.primary)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.toastMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(AppColors.borderNormal, lineWidth: 0.5)
            }
            .shadow(color: AppColors.toastShadow, radius: 12, x: 0, y: 4)
            .padding(.horizontal, 16)
    }
}

// MARK: - History Record Row

/// 历史记录列表行视图
struct HistoryRecordRow: View {
    let record: HistoryRecord
    let preferences: Preferences
    @Environment(\.l10n)
    private var l10n

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {  // 6 → 4
            // 顶部：模式图标 + 时间
            HStack(spacing: 4) {  // 6 → 4
                Image(systemName: modeIcon)
                    .foregroundColor(modeColor)
                    .font(.caption)

                Text(l10n.modeName(record.mode))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(relativeTimeString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // 输入预览
            Text(record.inputPreview)
                .lineLimit(2)
                .font(.body)
                .foregroundColor(.primary)

            // 输出预览
            if !record.output.isEmpty {
                Text(record.outputPreview)
                    .lineLimit(1)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)  // 4 → 2
    }

    private var modeIcon: String {
        switch record.mode {
        case .translate: return "arrow.left.arrow.right"
        case .polish: return "sparkles"
        case .summarize: return "doc.text"
        }
    }

    private var modeColor: Color {
        switch record.mode {
        case .translate: return .blue
        case .polish: return .purple
        case .summarize: return .green
        }
    }

    private var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: preferences.appLanguage.localeIdentifier ?? "en")
        return formatter.localizedString(for: record.timestamp, relativeTo: Date())
    }
}

// MARK: - Supporting Colors

private extension AppColors {
    static var inputBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    static var outputBackground: Color {
        Color(nsColor: .controlBackgroundColor).opacity(0.5)
    }
}
