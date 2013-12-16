//
//  ShadyAppDelegate.m
//  Shady
//
//  Created by Matt Gemmell on 02/11/2009.
//

#import "ShadyAppDelegate.h"
#import <QuartzCore/QuartzCore.h>
#import "MGTransparentWindow.h"
#import "NSApplication+DockIcon.h"

#define OPACITY_UNIT				0.05; // "20 shades ought to be enough for _anybody_."
#define DEFAULT_OPACITY				0.4

#define STATE_MENU					NSLocalizedString(@"Turn Shady Off", nil) // global status menu-item title when enabled
#define STATE_MENU_OFF				NSLocalizedString(@"Turn Shady On", nil) // global status menu-item title when disabled

#define HELP_TEXT					NSLocalizedString(@"When Shady is frontmost:\rPress Up/Down to alter shade,\ror press Q to Quit.", nil)
#define HELP_TEXT_OFF				NSLocalizedString(@"Shady is Off.\rPress S to turn Shady on,\ror press Q to Quit.", nil)

#define STATUS_MENU_ICON			[NSImage imageNamed:@"Shady_Menu_Dark"]
#define STATUS_MENU_ICON_ALT		[NSImage imageNamed:@"Shady_Menu_Light"]
#define STATUS_MENU_ICON_OFF		[NSImage imageNamed:@"Shady_Menu_Dark_Off"]
#define STATUS_MENU_ICON_OFF_ALT	[NSImage imageNamed:@"Shady_Menu_Light_Off"]

#define MAX_OPACITY					0.90 // the darkest the screen can be, where 1.0 is pure black.
#define KEY_OPACITY					@"ShadySavedOpacityKey" // name of the saved opacity setting.
#define KEY_DOCKICON				@"ShadySavedDockIconKey" // name of the saved dock icon state setting.
#define KEY_ENABLED					@"ShadySavedEnabledKey" // name of the saved primary state setting.

@implementation ShadyAppDelegate

@synthesize window;
@synthesize opacity;
@synthesize statusMenu;
@synthesize opacitySlider;
@synthesize prefsWindow;
@synthesize dockIconCheckbox;
@synthesize stateMenuItemMainMenu;
@synthesize stateMenuItemStatusBar;


#pragma mark Setup and Tear-down


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Set the default opacity value and load any saved settings.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
								[NSNumber numberWithFloat:DEFAULT_OPACITY], KEY_OPACITY, 
								[NSNumber numberWithBool:YES], KEY_DOCKICON, 
								[NSNumber numberWithBool:YES], KEY_ENABLED, 
								nil]];
	
	// Set up Dock icon.
	BOOL showsDockIcon = [defaults boolForKey:KEY_DOCKICON];
	[dockIconCheckbox setState:(showsDockIcon) ? NSOnState : NSOffState];
	if (showsDockIcon) {
		// Only set it here if it's YES, since we've just read a saved default and we always start with no Dock icon.
		[NSApp setShowsDockIcon:showsDockIcon];
	}
	
	// Create transparent window.
	NSRect screensFrame = [[NSScreen mainScreen] frame];
	for (NSScreen *thisScreen in [NSScreen screens]) {
		screensFrame = NSUnionRect(screensFrame, [thisScreen frame]);
	}
	window = [[MGTransparentWindow windowWithFrame:screensFrame] retain];
	
	// Configure window.
	[window setReleasedWhenClosed:YES];
	[window setHidesOnDeactivate:NO];
	[window setCanHide:NO];
	[window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
	[window setIgnoresMouseEvents:YES];
	[window setLevel:NSScreenSaverWindowLevel];
	[window setDelegate:self];
	
	// Configure contentView.
	NSView *contentView = [window contentView];
	[contentView setWantsLayer:YES];
	CALayer *layer = [contentView layer];
	layer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
	layer.opacity = 0;
	[window makeFirstResponder:contentView];
	
	// Activate statusItem.
	NSStatusBar *bar = [NSStatusBar systemStatusBar];
    statusItem = [bar statusItemWithLength:NSSquareStatusItemLength];
    [statusItem retain];
    [statusItem setImage:STATUS_MENU_ICON];
	[statusItem setAlternateImage:STATUS_MENU_ICON_ALT];
    [statusItem setHighlightMode:YES];
	[opacitySlider setFloatValue:(1.0 - opacity)];
    [statusItem setMenu:statusMenu];
	
	// Set appropriate initial display state.
	shadyEnabled = [defaults boolForKey:KEY_ENABLED];
	[self updateEnabledStatus];
	self.opacity = [defaults floatForKey:KEY_OPACITY];
	
	// Only show help text when activated _after_ we've launched and hidden ourselves.
	showsHelpWhenActive = NO;
	
	// Put this app into the background (the shade won't hide due to how its window is set up above).
	[NSApp hide:self];
	
	// Put window on screen.
	[window makeKeyAndOrderFront:self];
}


- (void)dealloc
{
	if (statusItem) {
		[[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
		[statusItem release];
		statusItem = nil;
	}
	[window removeChildWindow:helpWindow];
	[helpWindow close];
	[window close];
	window = nil; // released when closed.
	helpWindow = nil; // released when closed.
	
	[super dealloc];
}


#pragma mark Notifications handlers


- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{
	[self applicationActiveStateChanged:aNotification];
}


- (void)applicationDidResignActive:(NSNotification *)aNotification
{
	[self applicationActiveStateChanged:aNotification];
}


- (void)applicationActiveStateChanged:(NSNotification *)aNotification
{
	BOOL appActive = [NSApp isActive];
	if (appActive) {
		// Give the window a kick into focus, so we still get key-presses.
		[window makeKeyAndOrderFront:self];
	}
	
	if (!showsHelpWhenActive && !appActive) {
		// Enable help text display when active from now on.
		showsHelpWhenActive = YES;
		
	} else if (showsHelpWhenActive) {
		[self toggleHelpDisplay];
	}
}


#pragma mark IBActions


- (IBAction)showAbout:(id)sender
{
	// We wrap this for the statusItem to ensure Shady comes to the front first.
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp orderFrontStandardAboutPanel:self];
}


- (IBAction)showPreferences:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[prefsWindow makeKeyAndOrderFront:self];
}


- (IBAction)increaseOpacity:(id)sender
{
	// i.e. make screen darker by making our mask less transparent.
	if (shadyEnabled) {
		self.opacity = opacity + OPACITY_UNIT;
	} else {
		NSBeep();
	}
}


- (IBAction)decreaseOpacity:(id)sender
{
	// i.e. make screen lighter by making our mask more transparent.
	if (shadyEnabled) {
		self.opacity = opacity - OPACITY_UNIT;
	} else {
		NSBeep();
	}
}


- (IBAction)opacitySliderChanged:(id)sender
{
	self.opacity = (1.0 - [sender floatValue]);
}


- (IBAction)toggleDockIcon:(id)sender
{
	BOOL showsDockIcon = ([sender state] != NSOffState);
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:showsDockIcon forKey:KEY_DOCKICON];
	[defaults synchronize];
	[NSApp setShowsDockIcon:showsDockIcon];
}


- (IBAction)toggleEnabledStatus:(id)sender
{
	shadyEnabled = !shadyEnabled;
	[self updateEnabledStatus];
}


- (void)keyDown:(NSEvent *)event
{
	if ([event window] == window) {
		unsigned short keyCode = [event keyCode];
		if (keyCode == 12 || keyCode == 53) { // q || Esc
			[NSApp terminate:self];
			
		} else if (keyCode == 126) { // up-arrow
			[self decreaseOpacity:self];
			
		} else if (keyCode == 125) { // down-arrow
			[self increaseOpacity:self];
			
		} else if (keyCode == 1) { // s
			[self toggleEnabledStatus:self];
			
		} else if (keyCode == 43) { // ,
			[self showPreferences:self];
			
		} else {
			//NSLog(@"keyCode: %d", keyCode);
		}
	}
}


#pragma mark Helper methods


- (void)toggleHelpDisplay
{
	if (!helpWindow) {
		// Create helpWindow.
		NSRect mainFrame = [[NSScreen mainScreen] frame];
		NSRect helpFrame = NSZeroRect;
		float width = 600;
		float height = 200;
		helpFrame.origin.x = (mainFrame.size.width - width) / 2.0;
		helpFrame.origin.y = 200.0;
		helpFrame.size.width = width;
		helpFrame.size.height = height;
		helpWindow = [[MGTransparentWindow windowWithFrame:helpFrame] retain];
		
		// Configure window.
		[helpWindow setReleasedWhenClosed:YES];
		[helpWindow setHidesOnDeactivate:NO];
		[helpWindow setCanHide:NO];
		[helpWindow setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
		[helpWindow setIgnoresMouseEvents:YES];
		
		// Configure contentView.
		NSView *contentView = [helpWindow contentView];
		[contentView setWantsLayer:YES];
		CATextLayer *layer = [CATextLayer layer];
		layer.opacity = 0;
		[contentView setLayer:layer];
		CGColorRef bgColor = CGColorCreateGenericGray(0.0, 0.6);
		layer.backgroundColor = bgColor;
		CGColorRelease(bgColor);
		layer.string = (shadyEnabled) ? HELP_TEXT : HELP_TEXT_OFF;
		layer.contentsRect = CGRectMake(0, 0, 1, 1.2);
		layer.fontSize = 40.0;
		layer.foregroundColor = CGColorGetConstantColor(kCGColorWhite);
		layer.borderColor = CGColorGetConstantColor(kCGColorWhite);
		layer.borderWidth = 4.0;
		layer.cornerRadius = 15.0;
		layer.alignmentMode = kCAAlignmentCenter;
		
		[window addChildWindow:helpWindow ordered:NSWindowAbove];
	}
	
	if (showsHelpWhenActive) {
		float helpOpacity = (([NSApp isActive] ? 1 : 0));
		[[[helpWindow contentView] layer] setOpacity:helpOpacity];
	}
}


- (void)updateEnabledStatus
{
	// Save state.
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:shadyEnabled forKey:KEY_ENABLED];
	[defaults synchronize];
	
	// Show or hide the shade layer's view appropriately.
	[[[window contentView] animator] setHidden:!shadyEnabled];
	
	// Modify help text shown when we're frontmost.
	if (helpWindow) {
		CATextLayer *helpLayer = (CATextLayer *)[[helpWindow contentView] layer];
		helpLayer.string = (shadyEnabled) ? HELP_TEXT : HELP_TEXT_OFF;
	}
	
	// Update both enable/disable menu-items (in the main menubar and in the NSStatusItem's menu).
	[stateMenuItemMainMenu setTitle:(shadyEnabled) ? STATE_MENU : STATE_MENU_OFF];
	[stateMenuItemStatusBar setTitle:(shadyEnabled) ? STATE_MENU : STATE_MENU_OFF];
	
	// Update status item's regular and alt/selected images.
	[statusItem setImage:(shadyEnabled) ? STATUS_MENU_ICON : STATUS_MENU_ICON_OFF];
	[statusItem setAlternateImage:(shadyEnabled) ? STATUS_MENU_ICON_ALT : STATUS_MENU_ICON_OFF_ALT];
	
	// Enable/disable slider.
	[opacitySlider setEnabled:shadyEnabled];
}


#pragma mark Accessors


- (void)setOpacity:(float)newOpacity
{
	float normalisedOpacity = MIN(MAX_OPACITY, MAX(newOpacity, 0.0));
	if (normalisedOpacity != opacity) {
		opacity = normalisedOpacity;
		[[[window contentView] layer] setOpacity:opacity];
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setFloat:opacity forKey:KEY_OPACITY];
		[defaults synchronize];
		
		[opacitySlider setFloatValue:(1.0 - opacity)];
	}
}


@end
