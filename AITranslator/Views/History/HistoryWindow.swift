import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 历史记录主窗口
/// 包含搜索、筛选、列表和详情面板
struct HistoryWindow: View {
    @ObservedObject var historyManager: HistoryManager
    @ObservedObject var preferences: Preferences

    @State private var searchText: String = ""
    @State private var selectedMode: AppMode? = nil
    @State private var selectedRecord: HistoryRecord? = nil
    @State private var showDeleteConfirm: Bool = false
    @State private var showClearAllConfirm: Bool = false
    @State private var showImportOptions: Bool = false
    @State private var toastMessage: String? = nil

    /// 当前过滤后的记录列表
    private var filteredRecords: [HistoryRecord] {
        historyManager.searchAndFilter(
            query: searchText,
            mode: selectedMode
        )
    }

    /// 按日期分组的记录
    private var groupedRecords: [(String, [HistoryRecord])] {
        return historyManager.groupByDate(filteredRecords, appLanguage: preferences.appLanguage)
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
            L10n.tr("history.import.optionsTitle", lang: preferences.appLanguage),
            isPresented: $showImportOptions
        ) {
            Button(L10n.tr("history.confirm.cancel", lang: preferences.appLanguage), role: .cancel) {}
            Button(L10n.tr("history.import.merge", lang: preferences.appLanguage)) {
                performImport(merge: true)
            }
            Button(L10n.tr("history.import.replace", lang: preferences.appLanguage), role: .destructive) {
                performImport(merge: false)
            }
        } message: {
            Text(L10n.tr("history.import.optionsMessage", lang: preferences.appLanguage))
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
                    L10n.tr("history.search.placeholder", lang: preferences.appLanguage),
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
                    Text(L10n.tr("history.filter.all", lang: preferences.appLanguage))
                        .tag(nil as AppMode?)
                    ForEach(AppMode.allCases) { mode in
                        Text(mode.displayName).tag(mode as AppMode?)
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
                .help(L10n.tr("history.button.export", lang: preferences.appLanguage))
                .disabled(historyManager.records.isEmpty)

                // 导入按钮
                Button(action: { importHistory() }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 13))
                }
                .buttonCursor()
                .help(L10n.tr("history.button.import", lang: preferences.appLanguage))

                // 清空按钮
                Button(action: { showClearAllConfirm = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))  // 14 → 13
                }
                .buttonCursor()
                .help(L10n.tr("history.button.clear", lang: preferences.appLanguage))
                .disabled(historyManager.records.isEmpty)
            }
        }
    }

    // MARK: - Records List

    private var recordsListView: some View {
        ScrollViewReader { proxy in
            List(selection: $selectedRecord) {
                ForEach(groupedRecords, id: \.0) { groupName, records in
                    Section(header: Text(groupName).font(.headline).foregroundColor(.secondary)) {
                        ForEach(records) { record in
                            HistoryRecordRow(record: record, preferences: preferences)
                                .tag(record)
                                .contextMenu {
                                    Button(L10n.tr("history.contextMenu.copyInput", lang: preferences.appLanguage)) {
                                        copyToClipboard(record.input)
                                    }
                                    Button(L10n.tr("history.contextMenu.copyOutput", lang: preferences.appLanguage)) {
                                        copyToClipboard(record.output)
                                    }
                                    Divider()
                                    Button(L10n.tr("history.contextMenu.delete", lang: preferences.appLanguage), role: .destructive) {
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
                L10n.tr("history.empty.noRecords", lang: preferences.appLanguage) :
                L10n.tr("history.empty.noResults", lang: preferences.appLanguage)
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
                    Label(record.mode.displayName, systemImage: modeIcon(record.mode))
                        .font(.subheadline)
                        .foregroundColor(modeColor(record.mode))

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(record.model)
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
                    Text(L10n.tr("history.detail.input", lang: preferences.appLanguage))
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
                    Text(L10n.tr("history.detail.output", lang: preferences.appLanguage))
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
                    Button(L10n.tr("history.detail.copyInput", lang: preferences.appLanguage)) {
                        copyToClipboard(record.input)
                    }
                    .buttonCursor()

                    Button(L10n.tr("history.detail.copyOutput", lang: preferences.appLanguage)) {
                        copyToClipboard(record.output)
                    }
                    .buttonCursor()

                    Spacer()

                    Button(role: .destructive, action: {
                        showDeleteConfirm = true
                    }) {
                        Label(
                            L10n.tr("history.detail.delete", lang: preferences.appLanguage),
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
            L10n.tr("history.confirm.deleteTitle", lang: preferences.appLanguage),
            isPresented: $showDeleteConfirm
        ) {
            Button(L10n.tr("history.confirm.cancel", lang: preferences.appLanguage), role: .cancel) {}
            Button(L10n.tr("history.detail.delete", lang: preferences.appLanguage), role: .destructive) {
                historyManager.deleteRecord(id: record.id)
                selectedRecord = nil
            }
        } message: {
            Text(L10n.tr("history.confirm.deleteMessage", lang: preferences.appLanguage))
        }
        .alert(
            L10n.tr("history.confirm.clearTitle", lang: preferences.appLanguage),
            isPresented: $showClearAllConfirm
        ) {
            Button(L10n.tr("history.confirm.cancel", lang: preferences.appLanguage), role: .cancel) {}
            Button(L10n.tr("history.button.clear", lang: preferences.appLanguage), role: .destructive) {
                historyManager.clearAll()
                selectedRecord = nil
            }
        } message: {
            Text(L10n.tr("history.confirm.clearMessage", lang: preferences.appLanguage))
        }
    }

    private var emptyDetailPanel: some View {
        VStack(spacing: 12) {  // 16 → 12
            Image(systemName: "doc.text")
                .font(.system(size: 36))  // 48 → 36
                .foregroundColor(.secondary)

            Text(L10n.tr("history.detail.selectPrompt", lang: preferences.appLanguage))
                .font(.subheadline)  // headline → subheadline
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Import/Export Methods

    /// 导出历史记录
    private func exportHistory() {
        let savePanel = NSSavePanel()
        savePanel.title = L10n.tr("history.export.title", lang: preferences.appLanguage)
        savePanel.nameFieldStringValue = "history_\(Date().timeIntervalSince1970).json"
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }

            do {
                try historyManager.exportToJSON(url: url)
                let message = String(
                    format: L10n.tr("history.export.success", lang: preferences.appLanguage),
                    historyManager.records.count
                )
                showToast(message)
            } catch {
                let message = String(
                    format: L10n.tr("history.export.failure", lang: preferences.appLanguage),
                    error.localizedDescription
                )
                showToast(message)
            }
        }
    }

    /// 导入历史记录（显示选项对话框）
    private func importHistory() {
        let openPanel = NSOpenPanel()
        openPanel.title = L10n.tr("history.import.title", lang: preferences.appLanguage)
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
                message = String(
                    format: L10n.tr("history.import.success.merge", lang: preferences.appLanguage),
                    added
                )
            } else {
                message = String(
                    format: L10n.tr("history.import.success.replace", lang: preferences.appLanguage),
                    newCount
                )
            }
            showToast(message)

            // 清除当前选中的记录
            selectedRecord = nil
        } catch {
            let message = String(
                format: L10n.tr("history.import.failure", lang: preferences.appLanguage),
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

    private func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)

        // 显示复制成功提示
        let message = L10n.tr("history.toast.copied", lang: preferences.appLanguage)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {  // 6 → 4
            // 顶部：模式图标 + 时间
            HStack(spacing: 4) {  // 6 → 4
                Image(systemName: modeIcon)
                    .foregroundColor(modeColor)
                    .font(.caption)

                Text(record.mode.displayName)
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
