//
//  AppDelegate.swift
//  playsoundSwift
//
//  Created by DE4ME on 11.11.2021.
//

import Cocoa;
import SDL;
import SDL_Sound;

import SDL.OpenGL
import SDL.SDL_active
import SDL.SDL_audio
import SDL.SDL_cdrom
import SDL.SDL_cpuinfo
import SDL.SDL_endian
import SDL.SDL_error
import SDL.SDL_events
import SDL.SDL_joystick
import SDL.SDL_keyboard
import SDL.SDL_keysym
import SDL.SDL_loadso
import SDL.SDL_main
import SDL.SDL_mouse
import SDL.SDL_mutex
import SDL.SDL_rwops
import SDL.SDL_stdinc
import SDL.SDL_thread
import SDL.SDL_timer
import SDL.SDL_version
import SDL.SDL_video
import SDL.SysWM

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

