@import AppKit;
@import Metal;
@import QuartzCore;
@import simd;

#include "main_view.m"

static NSString *
AppName(void)
{
	NSBundle *bundle = [NSBundle mainBundle];
	return [bundle objectForInfoDictionaryKey:(__bridge NSString *)kCFBundleNameKey];
}

static NSMenu *
CreateMenu(void)
{
	NSMenu *menuBar = [[NSMenu alloc] init];

	NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
	[menuBar addItem:appMenuItem];

	NSMenu *appMenu = [[NSMenu alloc] init];
	appMenuItem.submenu = appMenu;

	NSString *quitMenuItemTitle = [NSString stringWithFormat:@"Quit %@", AppName()];
	NSMenuItem *quitMenuItem = [[NSMenuItem alloc] initWithTitle:quitMenuItemTitle
	                                                      action:@selector(terminate:)
	                                               keyEquivalent:@"q"];

	[appMenu addItem:quitMenuItem];

	return menuBar;
}

int
main(void)
{
	setenv("MTL_HUD_ENABLED", "1", 1);
	setenv("MTL_SHADER_VALIDATION", "1", 1);
	setenv("MTL_DEBUG_LAYER", "1", 1);
	setenv("MTL_DEBUG_LAYER_WARNING_MODE", "assert", 1);

	@autoreleasepool
	{
		[NSApplication sharedApplication];
		[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

		NSApp.mainMenu = CreateMenu();

		NSRect rect = NSMakeRect(100, 100, 1000, 700);

		NSWindowStyleMask style = NSWindowStyleMaskTitled | NSWindowStyleMaskResizable |
		                          NSWindowStyleMaskClosable |
		                          NSWindowStyleMaskMiniaturizable;
		NSWindow *window = [[NSWindow alloc] initWithContentRect:rect
		                                               styleMask:style
		                                                 backing:NSBackingStoreBuffered
		                                                   defer:NO];

		MainView *view = [[MainView alloc] initWithFrame:rect];
		window.contentView = view;

		[window makeKeyAndOrderFront:nil];
		[NSApp activateIgnoringOtherApps:YES];
		[NSApp run];
	}
}
