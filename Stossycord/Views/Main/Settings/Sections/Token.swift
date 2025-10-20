//
//  Token.swift
//  Stossycord
//
//  Created by Alex Badi on 19/10/2025.
//

import SwiftUI
import LocalAuthentication
import KeychainSwift
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct TokenSettings: View {
    @State private var showAlert = false
    @State private var isspoiler = true
    let keychain = KeychainSwift()
    let groupedBackgroundColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 4) {
                Text("settings.token.label")
                    .font(.headline)

                Spacer()

                tokenDisplay
            }

            Divider()

            if #available(iOS 26.0, *) {
                Button(role: .destructive) {
                    keychain.delete("token")
                    showAlert = true
                } label: {
                    Text("settings.button.logout")
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
                .padding(.horizontal, 16)
                .glassEffect(.clear.tint(.red).interactive())
                .foregroundColor(.white)
            } else {
                Button(role: .destructive) {
                    keychain.delete("token")
                    showAlert = true
                } label: {
                    Text("settings.button.logout")
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.red.opacity(0.1))
                )
                .foregroundColor(.white)
            }
        }
        .padding(.vertical, 4)
        .alert("settings.alert.tokenResetTitle", isPresented: $showAlert) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text("settings.alert.tokenResetMessage")
        }
    }

    private var tokenDisplay: some View {
        Group {
            if isspoiler {
                HStack {
                    Button(action: authenticate) {
                        Image(systemName: "lock.rectangle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            } else {
                let token = keychain.get("token") ?? ""
                Text(token.isEmpty ? "—" : token)
                    .font(.system(.body, design: .monospaced))
                    .contextMenu {
                        Button {
                            #if os(macOS)
                            if let token = keychain.get("token") {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(token, forType: .string)
                            }
                            #else
                            UIPasteboard.general.string = keychain.get("token") ?? ""
                            #endif
                        } label: {
                            Text("common.copy")
                        }
                    }
                    .onTapGesture {
                        isspoiler = true
                    }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 0)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(groupedBackgroundColor)
        )
    }

    func authenticate() {
        let context = LAContext()
        var error: NSError?

        // Check whether biometric authentication is possible
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            // It's possible, so go ahead and use it
            let reason = String(localized: "settings.auth.biometricReason")

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self.isspoiler = false
                    } else {
                        // Handle authentication errors
                        if let error = authenticationError as? LAError {
                            switch error.code {
                            case .userFallback:
                                // User chose to use fallback authentication (e.g., passcode)
                                self.authenticateWithPasscode()
                            case .biometryNotAvailable, .biometryNotEnrolled:
                                // Biometric authentication is not available or not set up
                                self.authenticateWithPasscode()
                            default:
                                print("Authentication failed: \(error.localizedDescription)")
                                self.isspoiler = true
                            }
                        }
                    }
                }
            }
        } else {
            // Biometric authentication is not available
            authenticateWithPasscode()
        }
    }

    func authenticateWithPasscode() {
        let context = LAContext()
        let reason = String(localized: "settings.auth.passcodeReason")

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.isspoiler = false
                } else {
                    let fallback = String(localized: "settings.auth.unknownError")
                    print("Passcode authentication failed: \(error?.localizedDescription ?? fallback)")
                    self.isspoiler = true
                }
            }
        }
    }
}