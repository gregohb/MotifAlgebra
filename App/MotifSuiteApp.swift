//
//  MotifSuiteApp.swift
//  MotifSuite
//
//  The app shell. Deliberately thin.
//
//  Everything this target owns is presentation. The mathematics lives in MotifAlgebra, which is
//  a separate module in Packages/MotifSuite and knows nothing about SwiftUI — that is the
//  layering the package header describes, enforced here by the module boundary rather than by
//  convention. When MotifApp becomes a real target, most of what is currently in this folder
//  moves down into the package and this file shrinks to a window declaration.
//

import SwiftUI

@main
struct MotifSuiteApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 560, minHeight: 420)
        }
        .windowResizability(.contentSize)
    }
}
