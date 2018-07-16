/*
 * Copyright (c) 2018 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#import <proto/exec.h>
#import <mui/MUIFramework.h>
#import "globaldefines.h"
#import "application.h"

int muiMain(int argc, char *argv[])
{
	Application *mapp = [[Application alloc] init];
	MCCPowerTerm *termobj = [[MCCPowerTerm alloc] init];
	MUIButton *buttons[3];

	[mapp setTitle:@APP_NAME];
	[mapp setDescription:@"Very simple DEbug TERMinal"];
	[mapp setApplicationVersion:@APP_VER];
	[mapp setAuthor:@APP_AUTHOR];
	[mapp setCopyright:@APP_COPYRIGHT];
	[mapp setTermobj: termobj];

	MUIGroup *g = [[[MUIGroup alloc] initWithObjects:
		[termobj autorelease],
		(mapp.buttonsgroup = [[[MUIGroup alloc] initWithObjects: 
			(buttons[0] = [[[MUIButton alloc] initWithLabel:@"connect to "SERIAL_CH34X_DEVICE_NAME] autorelease]),
			(buttons[1] = [[[MUIButton alloc] initWithLabel:@"connect to "SERIAL_PL2303_DEVICE_NAME] autorelease]),
			(buttons[2] = [[[MUIButton alloc] initWithLabel:@"connect to "SERIALNAME] autorelease]),
		nil] autorelease]),
	nil] autorelease];

	MUIWindow *w = [[[MUIWindow alloc] init] autorelease];
	w.title = @"DeTerm";
	w.rootObject = g;

	[mapp instantiateWithWindows:w, NULL];
	[mapp setup];
	[w notify:@selector(closeRequest) performSelector:@selector(quit) withTarget:[OBApplication currentApplication]];
	[buttons[0] notify:@selector(pressed) trigger:NO performSelector:@selector(connectCH34X) withTarget:mapp];
	[buttons[1] notify:@selector(pressed) trigger:NO performSelector:@selector(connectPL2303) withTarget:mapp];
	[buttons[2] notify:@selector(pressed) trigger:NO performSelector:@selector(connectRealSerial) withTarget:mapp];

	[w setOpen: YES];
	[mapp run];
	[w setOpen: NO];

	[mapp cleanup];
	[mapp release];

	return 0;
}
