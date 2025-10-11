//
//  WelcomeView.swift
//  Stossycord
//
//  Created by Stossy11 on 21/9/2024.
//

import SwiftUI

struct WelcomeView: View {
    @StateObject var webSocketService: WebSocketService
    let onCompletion: () -> Void
    @State private var path: [OnboardingStep] = []
    private var appIconImage: Image { AppResources.appIconImage }

    private enum OnboardingStep: Hashable {
        case privacy
        case login
        case success
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            landingContent
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if path.isEmpty {
                            NavigationLink(value: OnboardingStep.privacy) {
                                Text("Continue")
                                    .font(.headline)
                            }
                        }
                    }
                }
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .privacy:
                        PrivacyOnboardingView {
                            path.append(.login)
                        }
                    case .login:
                        LoginView(webSocketService: webSocketService) {
                            path.append(.success)
                        }
                            .padding()
                    case .success:
                        LoginSuccessView {
                            onCompletion()
                        }
                    }
                }
        }
        .interactiveDismissDisabled(path.last != .success)
    }

    private var landingContent: some View {
        VStack(spacing: 24) {
            appIconImage
            .resizable()
            .scaledToFit()
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(spacing: 8) {
            Text("Welcome to\nStossycord")
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)

            Text("A Native Discord Client for iOS")
                .font(.title2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onAppear {
            if !path.isEmpty {
            path.removeAll()
            }
        }
    }
}


