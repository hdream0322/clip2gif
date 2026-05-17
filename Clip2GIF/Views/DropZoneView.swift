import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct DropZoneView: View {
    let onDrop: (URL) -> Void
    /// 미지원 파일이 들어왔을 때 안내용. (조용히 무시하지 않음)
    var onReject: (URL) -> Void = { _ in }
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                )

            VStack(spacing: 14) {
                Image(systemName: "film.stack")
                    .font(.system(size: 56))
                    .foregroundColor(isTargeted ? .accentColor : .secondary)
                Text("비디오 파일을 여기에 드래그")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("또는 클릭해서 파일 선택")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text(SupportedVideo.displayList)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            openFilePicker()
        }
        .onDrop(of: [.movie, .fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "비디오 파일 선택"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        var allowed: [UTType] = [.movie, .video, .quickTimeMovie, .mpeg4Movie]
        for ext in SupportedVideo.extensions {
            if let t = UTType(filenameExtension: ext) {
                allowed.append(t)
            }
        }
        panel.allowedContentTypes = allowed

        if panel.runModal() == .OK, let url = panel.url {
            if SupportedVideo.isSupported(url) {
                onDrop(url)
            } else {
                onReject(url)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        VideoDrop.handle(providers, onAccept: onDrop, onReject: onReject)
    }
}
