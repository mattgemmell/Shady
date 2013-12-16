#import "MGTransparentWindow.h"

@implementation MGTransparentWindow


// Designated initializer.
- (id)initWithContentRect:(NSRect)contentRect 
                styleMask:(NSUInteger)aStyle 
                  backing:(NSBackingStoreType)bufferingType 
                    defer:(BOOL)flag {
    
    if (self = [super initWithContentRect:contentRect 
                                        styleMask:NSBorderlessWindowMask 
                                          backing:NSBackingStoreBuffered 
                                   defer:NO]) {
        
        [self setBackgroundColor:[NSColor clearColor]];
        [self setAlphaValue:1.0];
        [self setOpaque:NO];
        [self setHasShadow:NO];
    }
    
    return self;
}


// Convenience constructor.
+ (MGTransparentWindow *)windowWithFrame:(NSRect)frame
{
	MGTransparentWindow *window = [[self alloc] 
								   initWithContentRect:frame 
								   styleMask:NSBorderlessWindowMask 
								   backing:NSBackingStoreBuffered 
								   defer:NO];
	return [window autorelease];
}


- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (BOOL)canBecomeMainWindow
{
	return NO;
}


- (void)keyDown:(NSEvent *)event
{
	[[self delegate] keyDown:event];
}


@end
