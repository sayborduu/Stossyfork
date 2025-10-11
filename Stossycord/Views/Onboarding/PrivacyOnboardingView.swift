//
//  PrivacyOnboardingView.swift
//  Stossycord
//
//  Created by Alex Badi on 11/10/2025.
//

import SwiftUI

struct PrivacyOnboardingView: View {
    @AppStorage("privacyMode") private var privacyModeRawValue: String = PrivacyMode.defaultMode.rawValue
    @AppStorage("privacyCustomLoadEmojis") private var privacyCustomLoadEmojis: Bool = true
    let onContinue: () -> Void

    private var currentMode: PrivacyMode {
        PrivacyMode(rawValue: privacyModeRawValue) ?? PrivacyMode.defaultMode
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose your privacy mode")
                        .font(.title2.weight(.semibold))

                    Text("Pick the experience that suits you. You can change this later in settings.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)

            Section("Privacy Modes") {
                ForEach(PrivacyMode.allCases) { mode in
                    Button(action: {
                        privacyModeRawValue = mode.rawValue
                    }) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(mode == currentMode ? Color.accentColor : .secondary)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(mode.titleKey)
                                        .font(.headline)
                                    Spacer()
                                    if mode == currentMode {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }

                                Text(mode.descriptionKey)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }

            if currentMode == .custom {
                Section("Custom Controls") {
                    Toggle("Load Discord Emojis", isOn: $privacyCustomLoadEmojis)

                    Text("Disable this to only use Stossycord custom emojis.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section {
                VStack {
                    if #available(iOS 26.0, *) {
                        Button {
                            onContinue()
                        } label: {
                            Text("Continue")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .glassEffect(.clear.interactive())
                    } else {
                        Button {
                            onContinue()
                        } label: {
                            Text("Continue")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 16)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Privacy Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: ensureValidPrivacyMode)
    }

    private func ensureValidPrivacyMode() {
        guard PrivacyMode(rawValue: privacyModeRawValue) != nil else {
            privacyModeRawValue = PrivacyMode.defaultMode.rawValue
            return
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyOnboardingView(onContinue: {})
    }
}
