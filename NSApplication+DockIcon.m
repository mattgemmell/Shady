//
//  NSApplication+DockIcon.m
//  Hyperspaces
//
//  Created by Tony Arnold on 30/06/09.
//  Licensed under Creative Commons Attribution 2.5 - http://creativecommons.org/licenses/by/2.5/


#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

@implementation NSApplication (DockIcon)


- (void)setShowsDockIcon:(BOOL)flag {
	// this should be called from the application delegate's applicationDidFinishLaunching
	// method or from some controller object's awakeFromNib method
	// Neat dockless hack using Carbon from <a href="http://codesorcery.net/2008/02/06/feature-requests-versus-the-right-way-to-do-it" title="http://codesorcery.net/2008/02/06/feature-requests-versus-the-right-way-to-do-it">http://codesorcery.net/2008/02/06/feature-requests-versus-the-right-way-...</a>
	if (flag) {
		ProcessSerialNumber psn = { 0, kCurrentProcess };
		// display dock icon
		TransformProcessType(&psn, kProcessTransformToForegroundApplication);
		// enable menu bar
		SetSystemUIMode(kUIModeNormal, 0);
		// switch to Dock.app
		[[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:@"com.apple.dock" options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifier:nil];
		// switch back
		[[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
	} else {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:@"Relaunch Now"];
		[alert addButtonWithTitle:@"Later"];
		NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
		NSString *appName = [[NSFileManager defaultManager] displayNameAtPath: bundlePath];
		[alert setMessageText:[NSString stringWithFormat:@"You must now restart %@", appName]];
		[alert setInformativeText:@"Your new setting for the Dock icon won't show up until you relaunch this application."];
		[alert setAlertStyle:NSWarningAlertStyle];
		 NSInteger result = [alert runModal];
		if (result == NSAlertFirstButtonReturn) {
			[NSTask launchedTaskWithLaunchPath:@"/bin/sh" arguments:[NSArray arrayWithObjects:@"-c", [NSString stringWithFormat:@"sleep 1 ; /usr/bin/open '%@'", [[NSBundle mainBundle] bundlePath]], nil]];
			[NSApp terminate:self];
		}
	}
}


@end
