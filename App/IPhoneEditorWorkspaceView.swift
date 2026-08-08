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

            ScrollView {
                switch editorState.compactPanel {
                case .timeline:
                    WorkspaceTimelineOverview(editorState: editorState)
                case .effects:
                    AIWorkspaceView()
                case .project:
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
