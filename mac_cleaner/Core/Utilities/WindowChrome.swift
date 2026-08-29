//
//  WindowChrome.swift
//  mac_cleaner
//
//  Makes the macOS title bar follow the app theme by clearing the system
//  toolbar chrome so sidebar / content backgrounds extend to the window edge.
//  See WWDC24 “Tailor macOS windows with SwiftUI”.
//

import SwiftUI
import AppKit

/// Applies SwiftUI window-toolbar theming when available (macOS 15+).
struct ThemedWindowToolbar: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content
                .toolbar(removing: .title)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .toolbarColorScheme(colorScheme, for: .windowToolbar)
        } else {
            content
                .toolbarBackground(.hidden, for: .windowToolbar)
                .toolbarColorScheme(colorScheme, for: .windowToolbar)
        }
    }
}

extension View {
    func themedWindowToolbar() -> some View {
        modifier(ThemedWindowToolbar())
    }
}

/// Configures the hosting `NSWindow` so the theme fills under the traffic lights.
struct WindowChromeConfigurator: NSViewRepresentable {
    var background: Color

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = false
        DispatchQueue.main.async {
            Self.apply(to: view.window, background: background)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            Self.apply(to: nsView.window, background: background)
        }
    }

    private static func apply(to window: NSWindow?, background: Color) {
        guard let window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(background)
    }
}
