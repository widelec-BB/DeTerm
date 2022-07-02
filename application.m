/*
 * Copyright (c) 2018-2022 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#import <proto/icon.h>
#import <proto/dos.h>
#import <ob/OBFramework.h>
#import "globaldefines.h"
#import "terminal-window.h"
#import "application.h"

@implementation Application
{
	OBString *_startupConfigurationPath;
	OBString *_executablePath;
}

@synthesize lastConfiguration;
@synthesize executablePath = _executablePath;

-(id) init
{
	if ((self = [super init]))
	{
		BPTR lock;
		[OBLocalizedString openCatalog:@APP_TITLE ".catalog" withLocale:NULL];

		self.title = @APP_TITLE;
		self.author = @APP_AUTHOR;
		self.copyright = @APP_COPYRIGHT;
		self.applicationVersion = @APP_VERSION;
		self.usedClasses = [OBArray arrayWithObjects: @"PowerTerm.mcc", nil];

		self.description = OBL(@"Serial Port Terminal", @"Application Description");
		self.base = @APP_TITLE;

		[self parseWBStartupMessage];

		if (self.executablePath == nil)
		{
			if ((lock = Lock("PROGDIR:" APP_TITLE, SHARED_LOCK)))
			{
				UBYTE buffer[1024];

				if (NameFromLock(lock, buffer, sizeof(buffer)))
					_executablePath = [OBString stringWithCString: buffer encoding: MIBENUM_SYSTEM];

				UnLock(lock);
			}
		}

		self.diskObject = GetDiskObject((STRPTR)self.executablePath.nativeCString);

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
		return;

	[super instantiateWithWindows: tw, nil];

	[super loadENV];
	[tw loadConfiguration: self.lastConfiguration];

	tw.open = YES;

	if (_startupConfigurationPath != nil)
		[[OBRunLoop mainRunLoop] performSelector: @selector(parseConfigurationFile:) target: tw withObject: _startupConfigurationPath];

	[super run];

	for (id w in self)
	{
		if ([w isKindOfClass: [TerminalWindow class]])
			[w disconnect];
	}

	[super saveENV];
	[super saveENVARC];
}

-(VOID) closeWindow: (MUIWindow *)w
{
	[self removeObject: w];

	[w killAllNotifies];

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
	[aboutbox notify: @selector(open) trigger: NO performSelector: @selector(closeWindow:) withTarget: self withObject: aboutbox];
}

-(VOID) openNewTerminalWindow
{
	TerminalWindow *tw = [[TerminalWindow alloc] init];
	if (!tw)
		return;

	[self addObject: tw];
	tw.open = YES;
}

-(IPTR) export: (MUIDataspace *)dataspace
{
	OBJSONSerializer *serializer = [OBJSONSerializer serializer];
	OBData *data = [serializer serializeDictionary: self.lastConfiguration error: NULL];

	[dataspace setData: data forID: 10];

	return [super export: dataspace];
}

-(IPTR) import: (MUIDataspace *)dataspace
{
	OBJSONDeserializer *deserializer = [OBJSONDeserializer deserializer];
	OBDictionary *config = [deserializer deserializeAsDictionary: [dataspace dataForID: 10] error: NULL];

	if (config && [config isKindOfClass: [OBDictionary class]])
		self.lastConfiguration = config;

	return [super import: dataspace];
}

extern struct WBStartup *_WBenchMsg; // from startup code
-(VOID) parseWBStartupMessage
{
	OBString *fileName;
	UBYTE buffer[1024];
	struct WBArg;

	if (!_WBenchMsg)
		return;

	if (NameFromLock(_WBenchMsg->sm_ArgList[0].wa_Lock, buffer, sizeof(buffer)) != 0)
	{
		fileName = [OBString stringWithCString: _WBenchMsg->sm_ArgList[0].wa_Name encoding: MIBENUM_SYSTEM];
		_executablePath = [[OBString stringWithCString: buffer encoding: MIBENUM_SYSTEM] stringByAddingPathComponent: fileName];
	}

	if (_WBenchMsg->sm_NumArgs < 2)
		return;

	if (NameFromLock(_WBenchMsg->sm_ArgList[1].wa_Lock, buffer, sizeof(buffer)) == 0)
		return;

	fileName = [OBString stringWithCString: _WBenchMsg->sm_ArgList[1].wa_Name encoding: MIBENUM_SYSTEM];
	_startupConfigurationPath = [[OBString stringWithCString: buffer encoding: MIBENUM_SYSTEM] stringByAddingPathComponent: fileName];
}

@end
