//
//  Warning.swift
//  Stossycord
//
//  Created by Alex Badi on 19/10/2025.
//

import SwiftUI

struct DestructiveSettings: View {
    @AppStorage("allowDestructiveActions") private var allowDestructiveActions: Bool = false   
    @State private var showPopover: Bool = false
     
    var body: some View {
        Toggle("settings.toggle.allowDestructiveActions", isOn: Binding(
            get: { allowDestructiveActions },
            set: { newValue in
                if newValue {
                    showPopover = true
                } else {
                    allowDestructiveActions = false
                }
            }
        ))
            .help(Text("settings.toggle.allowDestructiveActions.help"))
            .foregroundColor(allowDestructiveActions ? .red : .primary)
            .sheet(isPresented: $showPopover) {
                destructiveConfirmation
            }
    }

    var destructiveConfirmation: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.yellow)
                    .padding(.vertical, 16)

                Text("settings.destructive.confirmTitle")
                    .font(.system(size: 38, weight: .bold))

                Text("settings.destructive.confirmDescription")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: 600, alignment: .leading)
            }
            .padding(.horizontal, 34)

            Spacer()

            VStack(spacing: 12) {
                if #available(iOS 26.0, *) {
                    Button(action: {
                        allowDestructiveActions = true
                        showPopover = false
                    }) {
                        Text("common.enable")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 40)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .glassEffect(.regular)

                    Button(action: {
                        allowDestructiveActions = false
                        showPopover = false
                    }) {
                        Text("common.nevermind")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 40)
                    }
                    .buttonStyle(.bordered)
                    .glassEffect(.regular)
                } else {
                    Button(action: {
                        allowDestructiveActions = true
                        showPopover = false
                    }) {
                        Text("common.enable")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    Button(action: {
                        allowDestructiveActions = false
                        showPopover = false
                    }) {
                        Text("common.nevermind")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 56)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .padding(.top, 20)
        .background {
            #if canImport(UIKit)
            Color(UIColor.systemBackground)
            #elseif canImport(AppKit)
            Color(NSColor.windowBackgroundColor)
            #else
            Color(.clear)
            #endif
        }
        #if !os(iOS)
        .frame(maxHeight: .infinity)
        #endif
    }
}