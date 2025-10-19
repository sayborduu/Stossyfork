import SwiftUI

struct SystemMessageView: View {
    private let text: Text

    init(_ text: String) {
        self.text = Text(text)
    }

    init(_ text: Text) {
        self.text = text
    }

    var body: some View {
        text
            .font(.callout)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
    }
}
