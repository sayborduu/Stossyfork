#if os(iOS)
import SwiftUI
import UIKit

struct CameraCaptureView: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIImagePickerController

    @Environment(\.dismiss) private var dismiss

    var onCapture: (URL) -> Void
    var onCancel: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraCaptureView

        init(parent: CameraCaptureView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            defer {
                parent.dismiss()
            }

            if let mediaURL = info[.mediaURL] as? URL {
                handleVideoSelection(from: mediaURL)
            } else if let image = info[.originalImage] as? UIImage {
                handleImageCapture(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
            parent.onCancel?()
        }

        private func handleImageCapture(_ image: UIImage) {
            guard let data = image.jpegData(compressionQuality: 0.9) else { return }
            let folderURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)

            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
                let fileURL = folderURL.appendingPathComponent("captured-image.jpg")
                try data.write(to: fileURL)
                DispatchQueue.main.async {
                    self.parent.onCapture(fileURL)
                }
            } catch {
                print("CameraCaptureView: Failed to save captured image - \(error.localizedDescription)")
            }
        }

        private func handleVideoSelection(from url: URL) {
            let folderURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)

            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
                let targetURL = folderURL.appendingPathComponent(url.lastPathComponent)
                try FileManager.default.copyItem(at: url, to: targetURL)
                DispatchQueue.main.async {
                    self.parent.onCapture(targetURL)
                }
            } catch {
                print("CameraCaptureView: Failed to save captured video - \(error.localizedDescription)")
            }
        }
    }
}
#endif
