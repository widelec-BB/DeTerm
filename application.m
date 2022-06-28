/*
 * Copyright (c) 2018-2022 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#import <proto/icon.h>
#import <ob/OBFramework.h>
#import "globaldefines.h"
#import "terminal-window.h"
#import "application.h"

@implementation Application

-(id) init
{
	if ((self = [super init]))
	{
		[OBLocalizedString openCatalog:@APP_TITLE ".catalog" withLocale:NULL];

		self.title = @APP_TITLE;
		self.author = @APP_AUTHOR;
		self.copyright = @APP_COPYRIGHT;
		self.applicationVersion = @APP_VERSION;

		self.description = OBL(@"Very simple DEbug TERMinal", @"Application Description");
		self.base = @APP_TITLE;
		self.diskObject = GetDiskObject("PROGDIR:" APP_TITLE);

		return self;
	}

	return nil;
}

-(VOID) dealloc
{
	if (self.diskObject)
		FreeDiskObject(self.diskObject);
}

-(VOID) run
{
	TerminalWindow *tw = [[TerminalWindow alloc] init];

	if (!tw)
	{
		// TODO: requester(?)
		return;
	}

	[super instantiateWithWindows: tw, nil];

	[super loadENV];

	tw.open = YES;

	[super run];

	[super saveENV];
	[super saveENVARC];
}

-(VOID) closeWindow: (MUIWindow *)w
{
	[self removeObject: w];

	if (self.objects.count == 0)
		[self quit];
}

-(VOID) about
{
	MCCAboutbox *aboutbox = [[MCCAboutbox alloc] init];

#ifdef __GIT_HASH__
	aboutbox.build = @__GIT_HASH__;
#endif
	aboutbox.credits = @"\33b%p\33n\n\t" APP_AUTHOR "\n";

	[self addObject: aboutbox];
	aboutbox.open = YES;
	[aboutbox notify: @selector(closeRequest) trigger: NO performSelector: @selector(closeWindow:) withTarget: self withObject: aboutbox];
}

@end
