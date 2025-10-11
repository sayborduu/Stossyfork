//
//  SettingsSection.swift
//  Stossycord
//
//  Created by Alex Badi on 11/10/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct SettingsSection<Content: View, Footer: View>: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey?

    private let content: Content
    private let footer: AnyView?

    init(
        title: LocalizedStringKey,
        description: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.description = description
        self.content = content()

        if Footer.self == EmptyView.self {
            self.footer = nil
        } else {
            self.footer = AnyView(footer())
        }
    }

    init(
        title: LocalizedStringKey,
        description: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content
    ) where Footer == EmptyView {
        self.init(
            title: title,
            description: description,
            content: content,
            footer: { EmptyView() }
        )
    }

    var body: some View {
        List {
            Section {
                content
            } footer: {
                footerView
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
    }

    private var footerView: some View {
        Group {
            if let footer {
                footer
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                EmptyView()
            }
        }
    }
}
