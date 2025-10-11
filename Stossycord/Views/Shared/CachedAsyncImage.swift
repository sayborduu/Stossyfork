import SwiftUI
import Foundation

#if os(iOS)
import UIKit

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .onChange(of: url) { _ in
            image = nil
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        let urlString = url.absoluteString
        
        if let cachedData = CacheService.shared.getCachedProfilePicture(url: urlString) {
            if let cachedImage = UIImage(data: cachedData) {
                self.image = cachedImage
                return
            }
        }
        
        guard !isLoading else { return }
        isLoading = true

        func fetchImage(from currentURL: URL, redirectCount: Int = 0) {
            var request = URLRequest(url: currentURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 30
            request.allowsConstrainedNetworkAccess = true
            request.allowsExpensiveNetworkAccess = true

            URLSession.shared.dataTask(with: request) { data, response, _ in
                if let httpResponse = response as? HTTPURLResponse,
                   (300...399).contains(httpResponse.statusCode),
                   let location = httpResponse.value(forHTTPHeaderField: "Location"),
                   redirectCount < 5,
                   let redirectedURL = URL(string: location, relativeTo: currentURL)?.absoluteURL {
                    fetchImage(from: redirectedURL, redirectCount: redirectCount + 1)
                    return
                }

                let finalURLString = currentURL.absoluteString

                DispatchQueue.main.async {
                    isLoading = false

                    if let data = data,
                       let httpResponse = response as? HTTPURLResponse,
                       (200...299).contains(httpResponse.statusCode),
                       let downloadedImage = UIImage(data: data) {
                        CacheService.shared.setCachedProfilePicture(data, url: finalURLString)
                        if finalURLString != urlString {
                            CacheService.shared.setCachedProfilePicture(data, url: urlString)
                        }
                        self.image = downloadedImage
                    }
                }
            }.resume()
        }

        fetchImage(from: url)
    }
}

#elseif os(macOS)
import AppKit

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var image: NSImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(nsImage: image))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
        .onChange(of: url) { _ in
            image = nil
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        let urlString = url.absoluteString
        
        if let cachedData = CacheService.shared.getCachedProfilePicture(url: urlString) {
            if let cachedImage = NSImage(data: cachedData) {
                self.image = cachedImage
                return
            }
        }
        
        guard !isLoading else { return }
        isLoading = true

        func fetchImage(from currentURL: URL, redirectCount: Int = 0) {
            var request = URLRequest(url: currentURL)
            request.httpMethod = "GET"
            request.timeoutInterval = 30
            request.allowsConstrainedNetworkAccess = true
            request.allowsExpensiveNetworkAccess = true

            URLSession.shared.dataTask(with: request) { data, response, _ in
                if let httpResponse = response as? HTTPURLResponse,
                   (300...399).contains(httpResponse.statusCode),
                   let location = httpResponse.value(forHTTPHeaderField: "Location"),
                   redirectCount < 5,
                   let redirectedURL = URL(string: location, relativeTo: currentURL)?.absoluteURL {
                    fetchImage(from: redirectedURL, redirectCount: redirectCount + 1)
                    return
                }

                let finalURLString = currentURL.absoluteString

                DispatchQueue.main.async {
                    isLoading = false

                    if let data = data,
                       let httpResponse = response as? HTTPURLResponse,
                       (200...299).contains(httpResponse.statusCode),
                       let downloadedImage = NSImage(data: data) {
                        CacheService.shared.setCachedProfilePicture(data, url: finalURLString)
                        if finalURLString != urlString {
                            CacheService.shared.setCachedProfilePicture(data, url: urlString)
                        }
                        self.image = downloadedImage
                    }
                }
            }.resume()
        }

        fetchImage(from: url)
    }
}
#endif