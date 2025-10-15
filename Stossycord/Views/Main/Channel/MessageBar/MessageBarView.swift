import SwiftUI
import UIKit

struct MessageBarView: View {
    let permissionStatus: ChannelPermissionStatus
    let placeholder: String
    let canSendCurrentMessage: Bool
    let useNativePicker: Bool

    @Binding var message: String
    @Binding var showNativePicker: Bool
    @Binding var showNativePhotoPicker: Bool
    @Binding var showCameraPicker: Bool
    @Binding var showingFilePicker: Bool
    @Binding var showingUploadPicker: Bool

    let onMessageChange: (String) -> Void
    let onSubmit: () -> Void

    @AppStorage("customEmojiStorageEnabled") private var customEmojiEnabled = false
    @AppStorage("customEmojiStoreID") private var storeID = ""
    @AppStorage("customEmojiBlobToken") private var blobToken = ""
    @AppStorage("customEmojiBackendURL") private var backendURL = ""
    @AppStorage("useCustomEmojiBackend") private var useCustomEmojiBackend = false
    @AppStorage("customEmojiHyperlinkText") private var hyperlinkText = ""

    @EnvironmentObject var customEmojiManager: CustomEmojiManager
    @State private var showEmojiPicker = false
    @State private var filteredEmojis: [VercelBlobService.Emoji] = []
    @FocusState private var isMessageFieldFocused: Bool

    private let baseInputHeight: CGFloat = 46

    var body: some View {
        VStack(spacing: 10) {
            if let restrictionReason = permissionStatus.restrictionReason {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)

                    Text(restrictionReason)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground).opacity(0.6))
                )
            }

            if permissionStatus.canSendMessages {
                HStack(alignment: .bottom, spacing: 12) {
                    attachmentButton

                    inputStack
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(barBackground)
        .onChange(of: isMessageFieldFocused) { focused in
            if !focused {
                showEmojiPicker = false
            }
        }
        .onChange(of: customEmojiManager.emojis) { _ in
            updateEmojiSuggestions(for: message)
        }
        .onChange(of: customEmojiManager.state) { _ in
            updateEmojiSuggestions(for: message)
        }
        
    }
}

private extension MessageBarView {
    @ViewBuilder
    var attachmentButton: some View {
        if permissionStatus.canAttachFiles {
            Button {
                if useNativePicker {
                    showNativePicker = true
                } else {
                    showingUploadPicker = true
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: baseInputHeight, height: baseInputHeight)
                    .foregroundStyle(.blue)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: baseInputHeight, style: .continuous)
                    .fill(Color.black.opacity(0.3))
            )
            .background(attachmentBackground)
            .confirmationDialog("Select Attachment", isPresented: $showNativePicker) {
                Button("Photos") {
                    showNativePhotoPicker = true
                }
                Button("Files") {
                    showingFilePicker = true
                }
                Button("Camera") {
                    guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
                    showCameraPicker = true
                }
                Button("Cancel", role: .cancel) { }
            }
            .frame(width: baseInputHeight, height: baseInputHeight)
        }
    }

    @ViewBuilder
    var inputStack: some View {
        HStack(alignment: .bottom, spacing: 0) {
            TextField(placeholder, text: $message, axis: .vertical)
                .lineLimit(1...6)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.leading)
                .padding(.vertical, 10)
                .padding(.leading, 6)
                .padding(.trailing, 60)
                .focused($isMessageFieldFocused)
                .onChange(of: message) { newValue in
                    onMessageChange(newValue)
                    updateEmojiSuggestions(for: newValue)
                }
                .onSubmit {
                    sendMessage()
                }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .frame(minHeight: baseInputHeight, alignment: .bottom)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.3))
        )
        .background(inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .topLeading) {
            if showEmojiPicker {
                EmojiSuggestionList(emojis: filteredEmojis, onSelect: { emoji in
                    insert(emoji: emoji)
                })
                .padding(.bottom, 4)
                .offset(y: -24)
                .zIndex(1)
            }
        }
        .overlay(alignment: .trailing) {
            if canSendCurrentMessage {
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.blue)
                        .padding(10)
                }
                .accessibilityLabel("Send Message")
                .padding(.trailing, 6)
            } else {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.gray)
                    .padding(10)
                    .opacity(0)
                    .padding(.trailing, 6)
            }
        }
    }

    @ViewBuilder
    var barBackground: some View {
        if #available(iOS 26.0, *) {
            Color.clear
        } else {
            Rectangle()
                .fill(.thinMaterial)
                .overlay(alignment: .top) {
                    Divider()
                        .opacity(0.35)
                }
        }
    }

    @ViewBuilder
    var attachmentBackground: some View {
        if #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .glassEffect(.clear.interactive())
                .background(.black.opacity(0.3))
        } else {
            RoundedRectangle(cornerRadius: baseInputHeight / 2, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        }
    }

    @ViewBuilder
    var inputBackground: some View {
        if #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 24.0))
                .background(.black.opacity(0.3))
        } else {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        }
    }

    private func sendMessage() {
        processMessage()
        showEmojiPicker = false
        onSubmit()
    }

    private func processMessage() {
        var processed = message
        let pattern = "::\\{([^}]+)\\}::"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsString = processed as NSString
            let matches = regex.matches(in: processed, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches.reversed() {
                let range = match.range(at: 1)
                if range.location != NSNotFound {
                    let content = nsString.substring(with: range)
                    let link = generateLink(for: content)
                    let text = hyperlinkText.isEmpty ? "" : "[\(hyperlinkText)](\(link))"
                    let fullText = hyperlinkText.isEmpty ? link : text
                    processed = processed.replacingOccurrences(of: "::{\(content)}::", with: fullText)
                }
            }
        }
        message = processed
    }

    private func generateLink(for content: String) -> String {
        let sanitizedStore = storeID.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedBackend = backendURL.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sanitizedStore.isEmpty else { return content }

        if sanitizedBackend.isEmpty || !useCustomEmojiBackend {
            return "https://\(sanitizedStore).public.blob.vercel-storage.com/\(content)"
        } else {
            return "\(sanitizedBackend)/\(sanitizedStore)/\(content)"
        }
    }

    private func extensionFromMime(_ mime: String?) -> String {
        guard let mime else { return "png" }
        switch mime {
        case "image/png": return "png"
        case "image/webp": return "webp"
        case "image/jpeg": return "jpg"
        case "image/gif": return "gif"
        default: return "png"
        }
    }

    private func updateEmojiSuggestions(for newValue: String) {
        guard shouldEnableSuggestions else {
            hideSuggestions()
            return
        }

        guard let (query, _) = currentEmojiQuery(in: newValue) else {
            hideSuggestions()
            return
        }

        let results: [VercelBlobService.Emoji]
        if query.isEmpty {
            results = Array(customEmojiManager.emojis.prefix(8))
        } else {
            let lowercasedQuery = query.lowercased()
            results = Array(customEmojiManager.emojis.filter { $0.displayName.lowercased().contains(lowercasedQuery) }.prefix(8))
        }

        filteredEmojis = results
        showEmojiPicker = !results.isEmpty
    }

    private var shouldEnableSuggestions: Bool {
        customEmojiEnabled && !storeID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !blobToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && customEmojiManager.state == .ready && isMessageFieldFocused && !customEmojiManager.emojis.isEmpty
    }

    private func currentEmojiQuery(in text: String) -> (String, Range<String.Index>)? {
        guard let range = queryRange(in: text) else { return nil }
        let query = String(text[range.lowerBound...].dropFirst(2))
        return (query, range)
    }

    private func hideSuggestions() {
        filteredEmojis = []
        showEmojiPicker = false
    }

    private func insert(emoji: VercelBlobService.Emoji) {
        let ext = extensionFromMime(emoji.contentType)
        let encryptedFilename: String
        if emoji.storageFilename.lowercased().contains(".stossymoji.") {
            encryptedFilename = emoji.storageFilename
        } else {
            encryptedFilename = "\(emoji.storageFilename).stossymoji.\(ext)"
        }
        replaceCurrentSuggestion(with: encryptedFilename)
    }

    private func replaceCurrentSuggestion(with replacement: String) {
        guard let range = currentSuggestionRange() else {
            message.append("::{\(replacement)}::")
            showEmojiPicker = false
            return
        }

        message.replaceSubrange(range, with: "::{\(replacement)}::")
        hideSuggestions()
    }

    private func currentSuggestionRange() -> Range<String.Index>? {
        guard let range = queryRange(in: message) else { return nil }
        return range
    }

    private func queryRange(in text: String) -> Range<String.Index>? {
        guard let range = text.range(of: "::", options: .backwards) else { return nil }
        if range.lowerBound > text.startIndex {
            let previousCharacter = text[text.index(before: range.lowerBound)]
            if previousCharacter == "}" {
                return nil
            }
        }

        var endIndex = range.upperBound
        while endIndex < text.endIndex {
            let character = text[endIndex]
            if character.isWhitespace || character == "\n" || character == "\t" {
                return endIndex == range.upperBound ? nil : range.lowerBound..<endIndex
            }
            if character == "{" || character == "}" {
                return nil
            }
            if character == ":" {
                return nil
            }
            if !isAllowedQueryCharacter(character) {
                return nil
            }
            endIndex = text.index(after: endIndex)
        }

        return range.lowerBound..<endIndex
    }

    private func isAllowedQueryCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_" || character == "-" || character == "."
    }

    private struct EmojiSuggestionList: View {
        let emojis: [VercelBlobService.Emoji]
        let onSelect: (VercelBlobService.Emoji) -> Void

        var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(emojis) { emoji in
                        Button {
                            onSelect(emoji)
                        } label: {
                            AsyncImage(url: emoji.downloadURL) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            } placeholder: {
                                ProgressView()
                                    .frame(width: 36, height: 36)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: 280)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground).opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    MessageBarView(
        permissionStatus: ChannelPermissionStatus(canSendMessages: true, canAttachFiles: true, restrictionReason: "ig you might be muted idk"),
        placeholder: "Message #general",
        canSendCurrentMessage: true,
        useNativePicker: true,
        message: .constant(""),
        showNativePicker: .constant(false),
        showNativePhotoPicker: .constant(false),
        showCameraPicker: .constant(false),
        showingFilePicker: .constant(false),
        showingUploadPicker: .constant(false),
        onMessageChange: { _ in },
        onSubmit: { }
    )
    .environmentObject(CustomEmojiManager())
}
