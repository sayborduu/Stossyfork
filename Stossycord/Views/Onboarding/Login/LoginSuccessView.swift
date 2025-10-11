//
//  LoginSuccessView.swift
//  Stossycord
//
//  Created by Alex Badi on 11/10/2025.
//

import SwiftUI

struct LoginSuccessView: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 96, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.blue, Color.blue.opacity(0.2))

                Text("You're done!")
                    .font(.largeTitle.weight(.bold))

                Text("You're all set to use Stossycord. Close this screen to start exploring.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            Spacer()

            Button {
                onFinish()
            } label: {
                Label("Start using Stossycord", systemImage: "paperplane.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onFinish()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.blue)
                }
            }
        }
        .interactiveDismissDisabled(false)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LoginSuccessView(onFinish: {})
    }
}
