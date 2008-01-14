//
//  XMLMatePlugIn.h
//  XMLMatePlugIn
//
//  Created by Todd Ditchendorf on 12/23/06.
//  Copyright 2006 Todd Ditchendorf. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class XMLMateController;

@protocol TMPlugInController
- (float)version;
@end


@interface XMLMatePlugIn : NSObject {
	XMLMateController *controller;
}
+ (NSBundle *)bundle;

- (id)initWithPlugInController:(id <TMPlugInController>)aController;

- (void)installMenuItems;

	// Actions
- (void)showPalette:(id)sender;

	// Accessors
- (id)controller;
- (void)setController:(id)newController;
@end
