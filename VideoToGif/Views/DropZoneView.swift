import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct DropZoneView: View {
    let onDrop: (URL) -> Void
    @State private var isTargeted = false

    private let validExtensions = ["mp4", "mov", "m4v", "avi", "webm"]

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
                Text("MP4, MOV, M4V, AVI, WebM")
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
        for ext in validExtensions {
            if let t = UTType(filenameExtension: ext) {
                allowed.append(t)
            }
        }
        panel.allowedContentTypes = allowed

        if panel.runModal() == .OK, let url = panel.url {
            if validExtensions.contains(url.pathExtension.lowercased()) {
                onDrop(url)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                if validExtensions.contains(url.pathExtension.lowercased()) {
                    DispatchQueue.main.async { onDrop(url) }
                }
            }
            return true
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.movie.identifier) { item, _ in
                guard let url = item as? URL else { return }
                if validExtensions.contains(url.pathExtension.lowercased()) {
                    DispatchQueue.main.async { onDrop(url) }
                }
            }
            return true
        }

        return false
    }
}
