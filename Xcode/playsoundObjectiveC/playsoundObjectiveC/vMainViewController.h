//
//  ViewController.h
//  playsoundObjectiveC
//
//  Created by DE4ME on 11.11.2021.
//

#import <Cocoa/Cocoa.h>

@interface vMainViewController : NSViewController

@property IBOutlet NSImageView* imageView;
@property IBOutlet NSTextField* nameTextField;
@property IBOutlet NSButton* playButton;

@property NSURL* url;

@end

