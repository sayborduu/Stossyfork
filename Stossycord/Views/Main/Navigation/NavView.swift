//
//  NavView.swift
//  Stossycord
//
//  Created by Stossy11 on 20/9/2024.
//

import SwiftUI

enum Tabs: Hashable {
    case home, dm, settings, search
}

struct NavView: View {
    @StateObject var webSocketService: WebSocketService
    @State private var selectedTab: Tabs = .home
    @AppStorage("useSettingsTabLabel") private var useSettingsTabLabel: Bool = true
    @StateObject private var presenceManager: PresenceManager
    @State private var isTransitioning: Bool = false
    
    init(webSocketService: WebSocketService) {
        _webSocketService = StateObject(wrappedValue: webSocketService)
        _presenceManager = StateObject(wrappedValue: PresenceManager(webSocketService: webSocketService))
    }
    
    var body: some View {
        #if os(macOS)
        NavigationView {
            legacyTabView()
        }
    #else
        iosTabView()
    #endif
    }
}

#if os(iOS)
extension NavView {
    @ViewBuilder
    private func iosTabView() -> some View {
        if #available(iOS 18.0, *) {
            modernTabView()
        } else {
            legacyTabView()
        }
    }

    @ViewBuilder
    @available(iOS 18.0, *)
    private func modernTabView() -> some View {
        let tabView = TabView(selection: $selectedTab) {
            Tab("Servers", systemImage: "house", value: Tabs.home) {
                ServerView(webSocketService: webSocketService)
            }
            
            Tab("DMs", systemImage: "envelope", value: Tabs.dm) {
                DMsView(webSocketService: webSocketService)
            }

            Tab(useSettingsTabLabel ? "Settings" : "Profile", systemImage: useSettingsTabLabel ? "gearshape" : "person.crop.circle", value: Tabs.settings) {
                Group {
                    if useSettingsTabLabel {
                        NavigationStack {
                            SettingsView()
                                .environmentObject(presenceManager)
                        }
                    } else {
                        ProfileView(webSocketService: webSocketService)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            Tab(value: Tabs.search, role: .search) {
                SearchView(webSocketService: webSocketService)
            }
        }
        .onChange(of: selectedTab, perform: handleTabChange)
        .onChange(of: useSettingsTabLabel) { newValue in
            handleSettingsTabLabelChange(newValue)
        }
        
        if #available(iOS 26.0, *) {
            tabView.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            tabView
        }
    }
    
    private func handleTabChange(_ tab: Tabs) {
        if tab == .search {
            print("search")
        }
    }
}
#endif

extension NavView {
    @ViewBuilder
    private func legacyTabView() -> some View {
        TabView(selection: $selectedTab) {
            ServerView(webSocketService: webSocketService)
                .tabItem {
                    Label("Servers", systemImage: "house")
                }
                .tag(Tabs.home)
            DMsView(webSocketService: webSocketService)
                .tabItem {
                    Label("DMs", systemImage: "envelope")
                }
                .tag(Tabs.dm)
            
            Group {
                if useSettingsTabLabel {
                    NavigationStack {
                        SettingsView()
                            .environmentObject(presenceManager)
                    }
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                } else {
                    ProfileView(webSocketService: webSocketService)
                        .tabItem {
                            Label("Profile", systemImage: "person.crop.circle")
                        }
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .tag(Tabs.settings)
        }
        .onChange(of: useSettingsTabLabel) { newValue in
            handleSettingsTabLabelChange(newValue)
        }
    }
    
    private func handleSettingsTabLabelChange(_ newValue: Bool) {
        // Only animate if we're currently on the settings/profile tab
        guard selectedTab == .settings else { return }
        
        isTransitioning = true
        
        withAnimation(.easeInOut(duration: 0.3)) {
            // Trigger the tab content change with animation
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isTransitioning = false
        }
    }
}