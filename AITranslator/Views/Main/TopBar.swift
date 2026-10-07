import AppKit
import SwiftUI

struct TopBar: View {
    @ObservedObject var viewModel: AppViewModel
    var temporarilyBlurAndRefocus: () -> Void
    @Environment(\.undoManager)
    private var undoManager
    @Environment(\.l10n)
    private var l10n
    @State private var isSwapping = false

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Picker(l10n("picker.source"), selection: Binding(
                    get: { viewModel.session.sourceLang },
                    set: { viewModel.setSourceLang($0) }
                )) {
                    ForEach(LanguageUtils.supported) { lang in
                        Text(lang.name).tag(lang.id)
                    }
                }
                .frame(width: 160)
                .disabled(viewModel.session.mode == .summarize)
                .help(l10n("picker.source.help"))
                .onChange(of: viewModel.session.sourceLang) { _, _ in
                    temporarilyBlurAndRefocus()
                }

                Button {
                    temporarilyBlurAndRefocus()
                    let prevSrc = viewModel.session.sourceLang
                    let prevTgt = viewModel.session.targetLang
                    if viewModel.session.mode == .translate {
                        // 触发旋转动画
                        withAnimation(Animations.bouncySpring) {
                            isSwapping = true
                        }

                        viewModel.swapLanguages()
                        undoManager?.registerUndo(withTarget: viewModel) { vm in
                            vm.restoreLanguages(source: prevSrc, target: prevTgt)
                        }

                        // 动画结束后重置
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isSwapping = false
                        }
                    }
                } label: {
                    Label(l10n("cmd.swapLanguages"), systemImage: "arrow.left.arrow.right.circle")
                        .labelStyle(.iconOnly)
                        .rotationEffect(isSwapping ? .degrees(180) : .zero)
                        .animation(Animations.bouncySpring, value: isSwapping)
                }
                .secondaryBorderedButton()
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .help(
                    viewModel.session.mode == .polish || viewModel.session.mode == .summarize
                        ? l10n("picker.swap.disabled")
                        : l10n("picker.swap.help")
                )
                .disabled(
                    viewModel.session.mode == .polish ||
                    viewModel.session.mode == .summarize ||
                    LanguageUtils.standardize(code: viewModel.session.sourceLang).lowercased() ==
                    LanguageUtils.standardize(code: viewModel.session.targetLang).lowercased()
                )
                .accessibilityLabel(l10n("picker.swap.a11y"))
                .accessibilityHint(l10n("picker.swap.hint"))

                Picker(l10n("picker.target"), selection: Binding(
                    get: { viewModel.session.targetLang },
                    set: { viewModel.setTargetLang($0) }
                )) {
                    ForEach(LanguageUtils.supported) { lang in
                        Text(lang.name).tag(lang.id)
                    }
                }
                .frame(width: 160)
                .disabled(viewModel.session.mode == .polish)
                .help(l10n("picker.target.help"))
                .onChange(of: viewModel.session.targetLang) { _, _ in
                    temporarilyBlurAndRefocus()
                }
            }

            Spacer()

            NativeModePicker(
                selection: viewModel.session.mode,
                titles: AppMode.allCases.map(modeTitle),
                enabledSegments: AppMode.allCases.map(viewModel.isModeAvailable)
            ) { mode in
                temporarilyBlurAndRefocus()
                viewModel.setMode(mode)
            }
            .help(l10n("picker.mode.help"))
            .accessibilityLabel(l10n("picker.mode"))
            .accessibilityHint(l10n("picker.mode.help"))
        }
        .padding(.horizontal, Metrics.outerPadding)
        .padding(.top, Metrics.outerPadding)
    }

    private func modeTitle(for mode: AppMode) -> String {
        switch mode {
        case .translate:
            return l10n("mode.translate")
        case .polish:
            return l10n("mode.polish")
        case .summarize:
            return l10n("mode.summarize")
        }
    }
}

private struct NativeModePicker: NSViewRepresentable {
    let selection: AppMode
    let titles: [String]
    let enabledSegments: [Bool]
    let onSelect: (AppMode) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: titles,
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.selectionChanged(_:))
        )
        control.segmentDistribution = .fillEqually
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)
        update(control, coordinator: context.coordinator)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        update(control, coordinator: context.coordinator)
    }

    private func update(_ control: NSSegmentedControl, coordinator: Coordinator) {
        coordinator.onSelect = onSelect

        for index in titles.indices where index < control.segmentCount {
            control.setLabel(titles[index], forSegment: index)
            control.setEnabled(enabledSegments.indices.contains(index) && enabledSegments[index], forSegment: index)
        }

        control.selectedSegment = AppMode.allCases.firstIndex(of: selection) ?? 0
        control.sizeToFit()
    }

    final class Coordinator: NSObject {
        var onSelect: (AppMode) -> Void

        init(onSelect: @escaping (AppMode) -> Void) {
            self.onSelect = onSelect
        }

        @objc
        func selectionChanged(_ sender: NSSegmentedControl) {
            let index = sender.selectedSegment
            guard AppMode.allCases.indices.contains(index) else { return }
            onSelect(AppMode.allCases[index])
        }
    }
}
