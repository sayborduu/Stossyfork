// 
// MessageTypes.swift
// Stossycord
//
// Created by Alex Badi on 19/10/25.

import SwiftUI

struct MessageTypesSettingsView: View {
    @AppStorage("visibleMessageTypeIDs") private var visibleMessageTypeIDsData: Data?

    private let excludedTypeIDs: Set<Int> = [0, 19]

    private var customizableTypeIDs: Set<Int> { MessageType.customizableIDs }

    private var orderedMessageTypes: [MessageType] {
        let customizable = messageTypes
            .filter { customizableTypeIDs.contains($0.id) && !excludedTypeIDs.contains($0.id) }
            .sorted { formattedName(for: $0).localizedCaseInsensitiveCompare(formattedName(for: $1)) == .orderedAscending }

        let nonCustomizable = messageTypes
            .filter { !customizableTypeIDs.contains($0.id) && !excludedTypeIDs.contains($0.id) }
            .sorted { formattedName(for: $0).localizedCaseInsensitiveCompare(formattedName(for: $1)) == .orderedAscending }

        return customizable + nonCustomizable
    }

    private var visibleMessageTypeIDs: Set<Int> {
        guard let data = visibleMessageTypeIDsData,
              let decoded = try? JSONDecoder().decode([Int].self, from: data) else {
            return customizableTypeIDs
        }
        return Set(decoded).intersection(customizableTypeIDs)
    }

    var body: some View {
        List {
            Section(header: Text("Available")) {
                ForEach(availableTypes, id: \.id) { type in
                    messageTypeToggle(for: type)
                }
            }

            Section(header: Text("Unavailable"), footer: footerText) {
                Text("These message types aren't currently supported and will not be shown.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                ForEach(unavailableTypes, id: \.id) { type in
                    messageTypeToggle(for: type)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Message Types")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var availableTypes: [MessageType] {
        orderedMessageTypes.filter { customizableTypeIDs.contains($0.id) }
    }

    private var unavailableTypes: [MessageType] {
        orderedMessageTypes.filter { !customizableTypeIDs.contains($0.id) }
    }

    private func messageTypeToggle(for type: MessageType) -> some View {
        let isCustomizable = customizableTypeIDs.contains(type.id)

        return Toggle(isOn: binding(for: type, isCustomizable: isCustomizable)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedName(for: type))
                    .font(.body)
                if !type.description.isEmpty {
                    Text(type.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(!isCustomizable)
        #if os(macOS)
        .toggleStyle(.checkbox)
        #endif
    }

    private func binding(for type: MessageType, isCustomizable: Bool) -> Binding<Bool> {
        Binding(
            get: {
                guard isCustomizable else { return false }
                return visibleMessageTypeIDs.contains(type.id)
            },
            set: { newValue in
                guard isCustomizable else { return }
                setMessageTypeVisibility(for: type.id, isVisible: newValue)
            }
        )
    }

    private func setMessageTypeVisibility(for id: Int, isVisible: Bool) {
        var updated = visibleMessageTypeIDs
        if isVisible {
            updated.insert(id)
        } else {
            updated.remove(id)
        }
        saveVisibleMessageTypeIDs(updated)
    }

    private func saveVisibleMessageTypeIDs(_ ids: Set<Int>) {
        let filtered = Array(ids.intersection(customizableTypeIDs))
        visibleMessageTypeIDsData = try? JSONEncoder().encode(filtered)
    }

    private func formattedName(for type: MessageType) -> String {
        type.name.replacingOccurrences(of: "_", with: " ").capitalized
    }

    @ViewBuilder
    private var footerText: some View {
        Text("Only message types with custom rendering can be toggled. Others are shown by default.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }
}