//
//  AppDelegate.m
//  playsoundObjectiveC
//
//  Created by DE4ME on 11.11.2021.
//

#import "AppDelegate.h"
@import SDL;
@import SDL_Sound;


@interface AppDelegate ()

@end


@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    SDL_Init(SDL_INIT_AUDIO);
    Sound_Init();
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    Sound_Quit();
    SDL_Quit();
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename{
    sender.keyWindow.contentViewController.representedObject = filename;
    return YES;
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end
