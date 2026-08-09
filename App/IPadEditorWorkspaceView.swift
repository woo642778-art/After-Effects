import SwiftUI

struct IPadEditorWorkspaceView: View {
    @ObservedObject var editorState: EditorWorkspaceState
    @ObservedObject var preview: CompositionPreviewController

    @AppStorage("vertex2.workspace.leftFraction") private var storedLeftFraction = 0.22
    @AppStorage("vertex2.workspace.rightFraction") private var storedRightFraction = 0.27
    @AppStorage("vertex2.workspace.timelineFraction") private var storedTimelineFraction = 0.32

    @State private var leftDragDelta: CGFloat = 0
    @State private var rightDragDelta: CGFloat = 0
    @State private var timelineDragDelta: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let toolbarHeight: CGFloat = 38
            let contentHeight = max(1, proxy.size.height - toolbarHeight)
            let leftFraction = CGFloat(storedLeftFraction) + leftDragDelta / max(1, proxy.size.width)
            let rightFraction = CGFloat(storedRightFraction) - rightDragDelta / max(1, proxy.size.width)
            let timelineFraction = CGFloat(storedTimelineFraction) - timelineDragDelta / contentHeight
            let metrics = AEWorkspaceLayoutPolicy.metrics(
                containerWidth: proxy.size.width,
                containerHeight: contentHeight,
                preset: editorState.activeWorkspace,
                leftFraction: leftFraction,
                rightFraction: rightFraction,
                timelineFraction: timelineFraction
            )

            VStack(spacing: 0) {
                AEWorkspaceToolbar(
                    editorState: editorState,
                    widthBand: metrics.widthBand,
                    onToggleLeftDrawer: {
                        editorState.isLeftDrawerPresented.toggle()
                        if editorState.isLeftDrawerPresented { editorState.isRightDrawerPresented = false }
                    },
                    onToggleRightDrawer: {
                        editorState.isRightDrawerPresented.toggle()
                        if editorState.isRightDrawerPresented { editorState.isLeftDrawerPresented = false }
                    }
                )

                workspaceBody(metrics: metrics, size: CGSize(width: proxy.size.width, height: contentHeight))
            }
            .background(AfterEffectsTheme.background)
        }
    }

    private func workspaceBody(metrics: AEWorkspaceMetrics, size: CGSize) -> some View {
        ZStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    if metrics.showsLeftDock {
                        leftDock(usesTabs: metrics.leftDockUsesTabs)
                            .frame(width: metrics.leftDockWidth)

                        verticalSplitHandle
                            .gesture(leftResizeGesture(totalWidth: size.width))
                    }

                    compositionPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if metrics.showsRightDock {
                        verticalSplitHandle
                            .gesture(rightResizeGesture(totalWidth: size.width))

                        rightInspector
                            .frame(width: metrics.rightDockWidth)
                    }
                }
                .frame(maxHeight: .infinity)

                horizontalSplitHandle
                    .gesture(timelineResizeGesture(totalHeight: size.height))

                timelinePanel
                    .frame(height: metrics.timelineHeight)
            }

            if metrics.widthBand == .narrow {
                narrowDrawerLayer(size: size)
            }
        }
    }

    @ViewBuilder
    private func leftDock(usesTabs: Bool) -> some View {
        if usesTabs {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(AELeftDockTab.allCases) { tab in
                        Button {
                            editorState.leftDockTab = tab
                        } label: {
                            Text(tab.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(editorState.leftDockTab == tab ? AfterEffectsTheme.primaryText : AfterEffectsTheme.secondaryText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)
                                .background(editorState.leftDockTab == tab ? AfterEffectsTheme.selection : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(AfterEffectsTheme.elevatedPanel)

                switch editorState.leftDockTab {
                case .project:
                    AEPanel(title: "Project", systemImage: "folder") {
                        AEProjectPanelContent()
                    }
                case .effects:
                    AEPanel(title: "Effects & Presets", systemImage: "sparkles") {
                        AEEffectsPanelContent()
                    }
                }
            }
        } else {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    AEPanel(title: "Project", systemImage: "folder") {
                        AEProjectPanelContent()
                    }
                    .frame(height: max(180, proxy.size.height * 0.52))

                    horizontalDivider

                    AEPanel(title: "Effects & Presets", systemImage: "sparkles") {
                        AEEffectsPanelContent()
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
    }

    private var compositionPanel: some View {
        AEPanel(title: "Composition", systemImage: "rectangle.on.rectangle") {
            EditorPreviewSurface(preview: preview, editorState: editorState)
                .padding(6)
        }
    }

    private var rightInspector: some View {
        AEPanel(title: "Effect Controls", systemImage: "slider.horizontal.3") {
            AEEffectControlsPanelContent()
        }
    }

    private var timelinePanel: some View {
        AEPanel(title: editorState.graphMode == nil ? "Timeline" : "Graph Editor", systemImage: "timeline.selection") {
            if editorState.graphMode == nil {
                AETimelineView(editorState: editorState)
            } else {
                ScrollView {
                    GraphEditorView(editorState: editorState)
                        .padding(7)
                }
            }
        }
    }

    @ViewBuilder
    private func narrowDrawerLayer(size: CGSize) -> some View {
        if editorState.isLeftDrawerPresented || editorState.isRightDrawerPresented {
            Color.black.opacity(0.36)
                .contentShape(Rectangle())
                .onTapGesture {
                    editorState.isLeftDrawerPresented = false
                    editorState.isRightDrawerPresented = false
                }

            if editorState.isLeftDrawerPresented {
                HStack(spacing: 0) {
                    leftDock(usesTabs: true)
                        .frame(width: min(360, max(280, size.width * 0.72)))
                        .shadow(color: .black.opacity(0.45), radius: 16, x: 6)
                    Spacer(minLength: 0)
                }
                .transition(.move(edge: .leading))
            }

            if editorState.isRightDrawerPresented {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    rightInspector
                        .frame(width: min(390, max(300, size.width * 0.74)))
                        .shadow(color: .black.opacity(0.45), radius: 16, x: -6)
                }
                .transition(.move(edge: .trailing))
            }
        }
    }

    private var verticalSplitHandle: some View {
        Rectangle()
            .fill(AfterEffectsTheme.border)
            .frame(width: 7)
            .overlay {
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Resize panel")
    }

    private var horizontalSplitHandle: some View {
        Rectangle()
            .fill(AfterEffectsTheme.border)
            .frame(height: 7)
            .contentShape(Rectangle())
            .accessibilityLabel("Resize timeline")
    }

    private var horizontalDivider: some View {
        Rectangle()
            .fill(AfterEffectsTheme.border)
            .frame(height: 1)
    }

    private func leftResizeGesture(totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in leftDragDelta = value.translation.width }
            .onEnded { value in
                let next = CGFloat(storedLeftFraction) + value.translation.width / max(1, totalWidth)
                storedLeftFraction = Double(next.clamped(to: 0.16...0.30))
                leftDragDelta = 0
            }
    }

    private func rightResizeGesture(totalWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in rightDragDelta = value.translation.width }
            .onEnded { value in
                let next = CGFloat(storedRightFraction) - value.translation.width / max(1, totalWidth)
                storedRightFraction = Double(next.clamped(to: 0.20...0.36))
                rightDragDelta = 0
            }
    }

    private func timelineResizeGesture(totalHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in timelineDragDelta = value.translation.height }
            .onEnded { value in
                let next = CGFloat(storedTimelineFraction) - value.translation.height / max(1, totalHeight)
                storedTimelineFraction = Double(next.clamped(to: 0.24...0.46))
                timelineDragDelta = 0
            }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
