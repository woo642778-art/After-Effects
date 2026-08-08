import SwiftUI

struct IPadEditorWorkspaceView: View {
    @ObservedObject var editorState: EditorWorkspaceState
    @ObservedObject var preview: CompositionPreviewController

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ScrollView {
                    VStack(spacing: 12) {
                        ProjectWorkspaceView()
                        MediaImportView()
                    }
                }
                .frame(minWidth: 250, idealWidth: 290, maxWidth: 340)

                EditorPreviewSurface(preview: preview, editorState: editorState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                ScrollView {
                    VStack(spacing: 10) {
                        EffectControlsView()
                        GraphEditorView(editorState: editorState)
                    }
                }
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 410)
            }
            .frame(maxHeight: .infinity)

            AETimelineView(editorState: editorState)
                .frame(minHeight: 220, idealHeight: 300, maxHeight: 390)
        }
        .padding(8)
    }
}
