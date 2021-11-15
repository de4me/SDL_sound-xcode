//
//  AppDelegate.swift
//  playsoundSwift
//
//  Created by DE4ME on 11.11.2021.
//

import Cocoa;
import SDL;
import SDL_Sound;

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        SDL_Init(.init(SDL_INIT_AUDIO));
        Sound_Init();
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        Sound_Quit();
        SDL_Quit();
    }
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        sender.keyWindow?.contentViewController?.representedObject = filename;
        return true;
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true;
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true;
    }

}

