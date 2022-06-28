/*
 * Copyright (c) 2018-2022 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#import <proto/exec.h>
#import <mui/MUIFramework.h>
#import "globaldefines.h"
#import "application.h"

#if !__has_feature(objc_arc)
#error "Automatic Reference Counting is disabled"
#endif

int muiMain(int argc, char *argv[])
{
	Application *mapp = [[Application alloc] init];
	MCCPowerTerm *termobj = [[MCCPowerTerm alloc] init];
	MUIButton *buttons[3];

	[mapp setTitle:@APP_TITLE];
	[mapp setDescription:@"Very simple DEbug TERMinal"];
	[mapp setApplicationVersion:@APP_VERSION];
	[mapp setAuthor:@APP_AUTHOR];
	[mapp setCopyright:@APP_COPYRIGHT];
	[mapp setTermobj: termobj];

	MUIGroup *g = [[MUIGroup alloc] initWithObjects:
		termobj,
		(mapp.buttonsgroup = [[MUIGroup alloc] initWithObjects: 
			(buttons[0] = [[MUIButton alloc] initWithLabel:@"connect to "SERIAL_CH34X_DEVICE_NAME]),
			(buttons[1] = [[MUIButton alloc] initWithLabel:@"connect to "SERIAL_PL2303_DEVICE_NAME]),
			(buttons[2] = [[MUIButton alloc] initWithLabel:@"connect to "SERIALNAME]),
		nil]),
	nil];

	MUIWindow *w = [[MUIWindow alloc] init];
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

	return 0;
}
