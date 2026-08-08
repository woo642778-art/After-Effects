import SwiftUI

struct IPhoneEditorWorkspaceView: View {
    @ObservedObject var editorState: EditorWorkspaceState
    @ObservedObject var preview: CompositionPreviewController

    var body: some View {
        VStack(spacing: 8) {
            EditorPreviewSurface(preview: preview, editorState: editorState)
            Picker("Panel", selection: $editorState.compactPanel) {
                Text("Timeline").tag(CompactEditorPanel.timeline)
                Text("Effects").tag(CompactEditorPanel.effects)
                Text("Project").tag(CompactEditorPanel.project)
            }
            .pickerStyle(.segmented)

            switch editorState.compactPanel {
            case .timeline:
                AETimelineView(editorState: editorState)
            case .effects:
                ScrollView {
                    VStack(spacing: 10) {
                        EffectControlsView()
                        GraphEditorView(editorState: editorState)
                    }
                }
            case .project:
                ScrollView {
                    VStack(spacing: 12) {
                        ProjectWorkspaceView()
                        MediaImportView()
                    }
                }
            }
        }
        .padding(8)
    }
}
