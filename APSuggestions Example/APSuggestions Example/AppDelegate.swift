//
//  AppDelegate.swift
//  APSuggestions Example
//
//  Created by आश्विन पौडेल  on 2021-01-04.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        window.windowController?.showWindow(nil)
        window.contentViewController = ViewController()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

