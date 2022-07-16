/*
 * Copyright (c) 2018-2022 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#import <proto/icon.h>
#import <proto/dos.h>
#import <ob/OBFramework.h>
#import <string.h>
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
#ifdef DEBUG
		[OBContext trapDeallocatedObjects: YES];
#endif
		[OBLocalizedString openCatalog:@APP_TITLE ".catalog" withLocale:NULL];

		if (!(_executablePath = [Application getExecutableName]))
			return nil;

		self.title = @APP_TITLE;
		self.author = @APP_AUTHOR;
		self.copyright = @APP_COPYRIGHT;
		self.applicationVersion = @APP_VERSION;
		self.usedClasses = [OBArray arrayWithObjects: @"PowerTerm.mcc", nil];
		self.description = OBL(@"Serial Port Terminal", @"Application Description");
		self.base = @APP_TITLE;
		self.diskObject = GetDiskObject((STRPTR)self.executablePath.nativeCString);

		_startupConfigurationPath = [Application getStartupConfigurationPath];

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
	OBString *credits = @"\33b%p\33n\n\t" APP_AUTHOR "\n\33b%I\33n\n\t";

	credits = [credits stringByAppendingString: OBL(@"cah nggunung from www.flaticon.com", @"Icon credits")];
	credits = [credits stringByAppendingString: @"\n\33b%t\33n\n\tJaca\n\tTcheko"];

#ifdef __GIT_HASH__
	aboutbox.build = @__GIT_HASH__;
#endif
	aboutbox.credits = credits;

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

	[dataspace setData: data forID: MAKE_ID('L', 'A', 'S', 'T')];

	return [super export: dataspace];
}

-(IPTR) import: (MUIDataspace *)dataspace
{
	OBJSONDeserializer *deserializer = [OBJSONDeserializer deserializer];
	OBDictionary *config = [deserializer deserializeAsDictionary: [dataspace dataForID: MAKE_ID('L', 'A', 'S', 'T')] error: NULL];

	if (config && [config isKindOfClass: [OBDictionary class]] && config.count > 0)
		self.lastConfiguration = config;

	return [super import: dataspace];
}

extern struct WBStartup *_WBenchMsg; // from startup code
+(OBString *) getStartupConfigurationPath
{
	OBString *fileName;
	UBYTE buffer[1024];
	struct WBArg;

	if (!_WBenchMsg)
		return nil;

	if (_WBenchMsg->sm_NumArgs < 2)
		return nil;

	if (NameFromLock(_WBenchMsg->sm_ArgList[1].wa_Lock, buffer, sizeof(buffer)) == 0)
		return nil;

	fileName = [OBString stringWithCString: _WBenchMsg->sm_ArgList[1].wa_Name encoding: MIBENUM_SYSTEM];
	return [[OBString stringWithCString: buffer encoding: MIBENUM_SYSTEM] stringByAddingPathComponent: fileName];
}

+(OBString *) getExecutableName
{
	OBString *executablePath = nil;
	UBYTE programName[PATH_MAX];
	struct WBArg;

	if (_WBenchMsg && _WBenchMsg->sm_NumArgs >= 1 && NameFromLock(_WBenchMsg->sm_ArgList[0].wa_Lock, programName, sizeof(programName)) != 0)
	{
		OBString *fileName = [OBString stringWithCString: _WBenchMsg->sm_ArgList[0].wa_Name encoding: MIBENUM_SYSTEM];
		executablePath = [[OBString stringWithCString: programName encoding: MIBENUM_SYSTEM] stringByAddingPathComponent: fileName];
	}
	else
	{
		LONG res = GetProgramName(programName, sizeof(programName));
		if (res == 0 || !strstr(programName, ":"))
		{
			UBYTE progdirPath[PATH_MAX] = {'P', 'R', 'O', 'G', 'D', 'I', 'R', ':', '\0'};
			BPTR lock;

			if (res != 0)
				AddPart(progdirPath, res ? FilePart(programName) : APP_TITLE, sizeof(progdirPath));

			if ((lock = Lock(progdirPath, SHARED_LOCK)))
			{
				if (NameFromLock(lock, progdirPath, sizeof(progdirPath)))
					executablePath = [OBString stringWithCString: progdirPath encoding: MIBENUM_SYSTEM];

				UnLock(lock);
			}
		}
		else // GetProgramName() returned absolute path, we can use it as is.
			executablePath = [OBString stringWithCString: programName encoding: MIBENUM_SYSTEM];
	}
	return executablePath;
}

@end
