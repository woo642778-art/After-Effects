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
                    AIWorkspaceView()
                }
                .frame(minWidth: 270, idealWidth: 310, maxWidth: 360)
            }
            .frame(maxHeight: .infinity)

            WorkspaceTimelineOverview(editorState: editorState)
                .frame(minHeight: 190, idealHeight: 250, maxHeight: 320)
        }
        .padding(8)
    }
}
