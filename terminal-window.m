/*
 * Copyright (c) 2018-2022 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#import <proto/exec.h>
#import <proto/charsets.h>
#import <proto/intuition.h>
#import <proto/muimaster.h>
#import <proto/icon.h>
#import <proto/dos.h>
#import <workbench/icon.h>
#import <clib/alib_protos.h>
#import <mui/muiFramework.h>

#import <string.h>
#import "globaldefines.h"
#import "application.h"
#import "terminal.h"
#import "terminal-window.h"

typedef enum
{
	SendModeInteractive = 0,
	SendModeLineBuffered,
} SendMode;

typedef enum
{
	MenuNewWindow = 0,
	MenuLoadConfigFrom,
	MenuSaveCurrentConfigAs,
	MenuTermReset,
	MenuDisconnect,
	MenuAbout,
	MenuAboutMUI,
	MenuQuit,
	MenuMUIPreferences,

	MenuLocalEchoOff = 40,
	MenuLocalEchoBeforeSend,
	MenuLocalEchoAfterSend,

	MenuSendModeInteractive = 45,
	MenuSendModeLineBuffered,

	MenuLFAsCRLF = 50,
	MenuCRAsCRLF,

	MenuTerminalEmulation = 256,
} Menu;

@implementation TerminalWindow
{
	__weak MUIGroup *_pageGroup;
	__weak MUIString *_unitString;
	__weak MUICycle *_devicesCycle, *_baudRateCycle, *_dataBitsCycle, *_parityCycle, *_stopBitsCycle, *_charsetCycle;
	__weak MUICheckmark *_xFlowCheckmark, *_eofModeCheckmark;
	__weak Terminal *_term;
	__weak MUIScrollbar *_scrollbar;

	__weak MUIMenu *_localEchoMenu, *_termEmulationModeMenu, *_sendModeMenu;
	__weak MUIMenuitem *_disconnectMenuitem, *_termEmulationMenuitems[5], *_localEchoMenuitems[3], *_sendModeMenuitems[2];
	__weak MUIMenuitem *_termResetMenuitem, *_CRAsCRLFMenuitem, *_LFAsCRLFMenuitem;

	SerialDevice *_serialDevice;
	ULONG _localEchoMode;
	ULONG _sendMode;
}

static LONG InstancesCounter = 0;
static BOOL Initialized = NO;
static OBArray *BaudRateOptions, *DataBitsOptions, *StopBitsOptions, *CharsetOptions;
static OBArray *ParityOptionsLabels, *CharsetOptionsLabels;

+(BOOL) setup
{
	OBMutableArray *charsetOptions, *charsetOptionsLabels;
	UBYTE systemCharsetName[255];
	ULONG systemCharsetMibenum;
	Boopsiobject *charsetsObj;

	if (Initialized)
		return YES;

	BaudRateOptions = [OBArray arrayWithObjects: @"75", @"150", @"300", @"600", @"1200", @"1800", @"2400", @"3600", @"4800", @"7200", @"9600", @"1440",
	  @"19200", @"28800", @"38400", @"57600", @"115200", @"230400", @"460800", @"614400", @"921600", @"1228800", @"2457600", @"3000000", @"6000000", nil];
	if (!BaudRateOptions)
		return NO;

	DataBitsOptions = [OBArray arrayWithObjects: @"5", @"6", @"7", @"8", nil];
	if (!DataBitsOptions)
		return NO;

	ParityOptionsLabels = [OBArray arrayWithObjects:
		OBL(@"None", @"Label for parity settings (turned off)"),
		OBL(@"Even", @"Label for parity settings (parity on even bits)"),
		OBL(@"Odd", @"Label for parity settings (parity on odd bits)"),
	nil];
	if (!ParityOptionsLabels)
		return NO;

	StopBitsOptions = [OBArray arrayWithObjects: @"1", @"2", nil];
	if (!StopBitsOptions)
		return NO;

	systemCharsetName[0] = 0x00;
	systemCharsetMibenum = GetSystemCharset(systemCharsetName, sizeof(systemCharsetName));

	charsetOptionsLabels = [OBMutableArray arrayWithCapacity: 50];
	[charsetOptionsLabels addObjectsFromArray: [OBArray arrayWithObjects:
		OBL(@"Raw (no conversion)", @"No conversion option for charset encoding"),
		@"US ASCII",
		@"UTF-8",
		[OBString stringWithFormat: OBL(@"%s (local)", @"Label for system charset encoding"), systemCharsetName],
	nil]];
	if (!charsetOptionsLabels)
		return NO;

	charsetOptions = [OBMutableArray arrayWithCapacity: 50];
	[charsetOptions addObjectsFromArray: [OBArray arrayWithObjects:
		[OBNumber numberWithUnsignedLong: MIBENUM_INVALID],
		[OBNumber numberWithUnsignedLong: MIBENUM_US_ASCII],
		[OBNumber numberWithUnsignedLong: MIBENUM_UTF_8],
		[OBNumber numberWithUnsignedLong: MIBENUM_SYSTEM],
	nil]];
	if (!charsetOptions)
		return NO;

	if ((charsetsObj = NewObjectA(NULL, "charsets.list", NULL)))
	{
		CONST_STRPTR name;
		ULONG mibenum = 0;

		while ((mibenum = DoMethod(charsetsObj, CLSM_NextCharsetNumber)))
		{
			if (mibenum == MIBENUM_UTF_8 || mibenum == MIBENUM_US_ASCII || mibenum == systemCharsetMibenum) // already added
				continue;

			name = GetCharsetName(mibenum, NULL, NULL);

			[charsetOptions addObject: [OBNumber numberWithUnsignedLong: mibenum]];
			[charsetOptionsLabels addObject: [OBString stringWithCString: name encoding: MIBENUM_SYSTEM]];
		}
		DisposeObject(charsetsObj);
	}

	CharsetOptions = charsetOptions;
	CharsetOptionsLabels = charsetOptionsLabels;

	Initialized = YES;

	return YES;
}

+(VOID) cleanup
{
	Initialized = NO;

	CharsetOptions = nil;
	CharsetOptionsLabels = nil;
	StopBitsOptions = nil;
	ParityOptionsLabels = nil;
	DataBitsOptions = nil;
	BaudRateOptions = nil;
}

-(id) init
{
	if ([TerminalWindow setup])
	{
		Terminal *termobj = [[Terminal alloc] init];

		if (termobj && (self = [super init]))
		{
			LONG i;
			MUIGroup *deviceConfigGroup;
			MUIButton *connectButton;
			MUICheckmark *xFlowCheckmark, *eofModeCheckmark;
			MUIText *labels[6];

			_term = termobj;

			deviceConfigGroup = [MUIGroup groupWithObjects:
				[MUIGroup groupWithColumns: 2 objects:
					labels[0] = [MUIText textWithContents: OBL(@"Device:", @"Label for cycle with available devices")],
					[MUIGroup horizontalGroupWithObjects:
						_devicesCycle = [MUICycle cycleWithEntries: [SerialDevice availableDevices]],
						_unitString = [MUIString stringWithContents: @"0"],
					nil],
					labels[1] = [MUIText textWithContents: OBL(@"Baud Rate:", @"Label for cycle with baud rate selection")],
					_baudRateCycle = [MUICycle cycleWithEntries: BaudRateOptions],
					labels[2] = [MUIText textWithContents: OBL(@"Data Bits:", @"Label for cycle with data bits selection")],
					_dataBitsCycle = [MUICycle cycleWithEntries: DataBitsOptions],
					labels[3] = [MUIText textWithContents: OBL(@"Parity:", @"Label for cycle with parity mode selection")],
					_parityCycle = [MUICycle cycleWithEntries: ParityOptionsLabels],
					labels[4] = [MUIText textWithContents: OBL(@"Stop Bits:", @"Label for cycle with number of stop bits selection")],
					_stopBitsCycle = [MUICycle cycleWithEntries: StopBitsOptions],
					labels[5] = [MUIText textWithContents: OBL(@"Text Encoding:", @"Label for cycle to select received text encoding")],
					_charsetCycle = [MUICycle cycleWithEntries: CharsetOptionsLabels],
				nil],
				[MUIGroup horizontalGroupWithObjects:
					[MUIRectangle rectangle],
					[MUICheckmark checkmarkWithLabel: OBL(@"X-ON/X-OFF Flow Control", @"Label for checkmark activating flow control") checkmark: &xFlowCheckmark],
					[MUICheckmark checkmarkWithLabel: OBL(@"EOF Mode", @"Label for checkmark activating EOF mode") checkmark: &eofModeCheckmark],
					[MUIRectangle rectangle],
				nil],
			nil];
			deviceConfigGroup.frame = MUIV_Frame_Group;
			deviceConfigGroup.frameTitle = OBL(@"Connection", @"Connection configuration group title");

			self.rootObject = [MUIGroup horizontalGroupWithObjects:
				_pageGroup = [MUIGroup groupWithPages:
					[MUIGroup groupWithObjects:
						[MUIRectangle rectangle],
						deviceConfigGroup,
						[MUIGroup horizontalGroupWithObjects:
							[MUIRectangle rectangle],
							connectButton = [MUIButton buttonWithLabel: OBL(@"Connect", @"Button for configuration confirmation")],
							[MUIRectangle rectangle],
						nil],
						[MUIRectangle rectangle],
					nil],
					[MUIGroup groupWithObjects: _term, nil],
				nil],
				_scrollbar = [MUIScrollbar verticalScrollbar],
			nil];
			self.title = @APP_TITLE;
			self.menustrip = [self createMenustrip];
			self.useRightBorderScroller = YES;

			_scrollbar.useWinBorder = MUIV_Prop_UseWinBorder_Right;

			for (i = 0; i < sizeof(labels) / sizeof(*labels); i++)
			{
				labels[i].preParse = @"\33r";
				labels[i].weight = 1;
				labels[i].frame = MUIV_Frame_String;
			}
			_unitString.weight = 5;
			_unitString.accept = @"0123456789";

			/* set some sensible defaults */
			_baudRateCycle.active = 16; // 115200
			_dataBitsCycle.active = 3; // 8
			_parityCycle.active = ParityNone;
			_charsetCycle.active = 0; // write raw data = no conversion
			self.localEchoMode = MenuLocalEchoOff;
			self.sendMode = MenuSendModeInteractive;
			self.terminalEmulationMode = MUIV_PowerTerm_Emulation_TTY;
			_term.cRasCRLF = YES;
			_unitString.integer = 0;

			_xFlowCheckmark = xFlowCheckmark;
			_eofModeCheckmark = eofModeCheckmark;

			[self loadConfiguration: ((Application *)self.applicationObject).lastConfiguration];

			[connectButton notify: @selector(pressed) trigger: NO performSelector: @selector(connect) withTarget: self];
			[_term notify: @selector(outLen) performSelector: @selector(handleNewTermInput) withTarget: self];

			InstancesCounter++;
		}
	}

	return self;
}

-(Boopsiobject *) instantiate
{
	Boopsiobject *obj = [super instantiate];

	_term.scroller = _scrollbar; /* needs to be set after instantiation of boopsi objects. bug? */

	return obj;
}

-(VOID) dealloc
{
	if (--InstancesCounter == 0)
		[TerminalWindow cleanup];
}

-(VOID) setCloseRequest: (BOOL)closerequest
{
	if (!closerequest)
		return;

	self.open = NO;
	[self disconnect];

	[(Application *)self.applicationObject closeWindow: self];
}

-(VOID) connect
{
	OBString *deviceName = [_devicesCycle.entries objectAtIndex: _devicesCycle.active];
	ULONG unit = _unitString.integer;
	ULONG baudRate = [[BaudRateOptions objectAtIndex: _baudRateCycle.active] unsignedIntValue];
	UBYTE dataBits = [[DataBitsOptions objectAtIndex: _dataBitsCycle.active] unsignedIntValue];
	UBYTE stopBits = [[StopBitsOptions objectAtIndex: _stopBitsCycle.active] unsignedIntValue];
	BOOL xFlow = _xFlowCheckmark.selected;
	BOOL eofMode = _eofModeCheckmark.selected;
	Parity parity = (Parity)_parityCycle.active;
	SerialDeviceError err;

	_serialDevice = [[SerialDevice alloc] init: deviceName unit: unit];
	if (!_serialDevice)
		return;

	_serialDevice.delegate = self;

	err = [_serialDevice openWithBaudRate: baudRate dataBits: dataBits stopBits: stopBits parity: parity xFlow: xFlow eofMode: eofMode];
	if (err != 0)
	{
		OBString *message = [SerialDevice errorMessage: err];
		MUIRequest *req = [MUIRequest requestWithTitle: OBL(@"Error", @"Requester title for error")
		   message: message buttons: [OBArray arrayWithObjects: OBL(@"_OK", @"Error requester confirmation button"), nil]];
		[req requestWithWindow: self];
		return;
	}

	_pageGroup.activePage = 1;

	_termResetMenuitem.enabled = YES;
	_disconnectMenuitem.enabled = YES;

	[self saveCurrentConfiguration];
}

-(VOID) disconnect
{
	_pageGroup.activePage = 0;

	_termResetMenuitem.enabled = NO;
	_disconnectMenuitem.enabled = NO;

	[_term reset];

	_serialDevice = nil;
}

-(VOID) receiveFromSerialDevice: (SerialDeviceError)err data: (OBData *)data
{
	if (err == 0)
	{
		DumpBinaryData((UBYTE *)data.bytes, data.length);
		[_term write: data encoding: [[CharsetOptions objectAtIndex: _charsetCycle.active] unsignedLongValue]];
	}
	else
		[self displayErrorRequester: err];
}

-(VOID) writeResultFromSerialDevice: (SerialDeviceError)err data: (OBData *)data
{
	if (err == 0)
	{
		if (_localEchoMode == MenuLocalEchoAfterSend)
			[_term write: data encoding: MIBENUM_UTF_8];
	}
	else
		[self displayErrorRequester: err];
}

-(VOID) displayErrorRequester: (SerialDeviceError)err
{
	MUIRequest *req = [MUIRequest requestWithTitle: OBL(@"Serial Device Error", @"Requester title for serial device error") message: [SerialDevice errorMessage: err]
	   buttons: [OBArray arrayWithObjects: OBL(@"_Ignore", @"Ignore error button"), OBL(@"_Disconnect", @"Disconnect after error button"), nil]];

	if ([req requestWithWindow: self] == 0)
		[self disconnect];
}

-(VOID) handleNewTermInput
{
	static LONG nextEchoStart = 0;
	UBYTE lastChar = *((UBYTE *)_term.outPtr + _term.outLen - 1);

	if (_localEchoMode == MenuLocalEchoBeforeSend)
	{
		[_term write: [OBData dataWithBytes: _term.outPtr + nextEchoStart length: _term.outLen - nextEchoStart] encoding: MIBENUM_UTF_8];
		nextEchoStart = _term.outLen;
	}
	if (_sendMode == MenuSendModeInteractive || lastChar == 0x0D || lastChar == 0x0A)
	{
		[_serialDevice write: [OBData dataWithBytes: _term.outPtr length: _term.outLen]];
		[_term outFlush];
		nextEchoStart = 0;
		return;
	}
}

-(MUIMenustrip *) createMenustrip
{
	MUIMenustrip *s;

	s = [MUIMenustrip menustripWithObjects:
		[[MUIMenu alloc] initWithTitle: @APP_TITLE objects:
			[MUIMenuitem itemWithTitle: OBL(@"Open New Terminal Window...", @"Menu entry label") shortcut: @"n" userData: MenuNewWindow],
			[MUIMenuitem barItem],
			[MUIMenuitem itemWithTitle: OBL(@"Load Configuration From...", @"Menu entry label") shortcut: nil userData: MenuLoadConfigFrom],
			[MUIMenuitem itemWithTitle: OBL(@"Save Current Configuration As...", @"Menu entry label") shortcut: nil userData: MenuSaveCurrentConfigAs],
			[MUIMenuitem barItem],
			_termResetMenuitem = [MUIMenuitem itemWithTitle: OBL(@"Reset Terminal", @"Menu entry label") shortcut: @"z" userData: MenuTermReset],
			_disconnectMenuitem = [MUIMenuitem itemWithTitle: OBL(@"Disconnect", @"Menu entry label") shortcut: @"c" userData: MenuDisconnect],
			[MUIMenuitem barItem],
			[MUIMenuitem itemWithTitle: OBL(@"About...", @"Menu entry label") shortcut: OBL(@"?", @"Menu About entry shortcut") userData: MenuAbout],
			[MUIMenuitem itemWithTitle: OBL(@"About MUI...", @"Menu entry label") shortcut: nil userData: MenuAboutMUI],
			[MUIMenuitem barItem],
			[MUIMenuitem itemWithTitle: OBL(@"Quit", @"Menu quit") shortcut: OBL(@"Q", @"Menu quit shortcut") userData: MenuQuit],
		nil],
		[[MUIMenu alloc] initWithTitle: OBL(@"Preferences", @"Menu entry label for preferences") objects:
			_localEchoMenu = [MUIMenu menuWithTitle: OBL(@"Local Echo Mode...", @"Menu for local echo mode selection") objects:
				_localEchoMenuitems[0] = [MUIMenuitem checkmarkItemWithTitle: OBL(@"Off", @"Local echo off menu label") shortcut: nil userData: MenuLocalEchoOff checked: YES],
				_localEchoMenuitems[1] = [MUIMenuitem checkmarkItemWithTitle: OBL(@"Before Send", @"Local echo before send") shortcut: nil userData: MenuLocalEchoBeforeSend checked: NO],
				_localEchoMenuitems[2] = [MUIMenuitem checkmarkItemWithTitle: OBL(@"After Send", @"Local echo after send") shortcut: nil userData: MenuLocalEchoAfterSend checked: NO],
			nil],
			_sendModeMenu = [MUIMenu menuWithTitle: OBL(@"Send Mode...", @"Menu for send mode selection") objects:
				_sendModeMenuitems[0] = [MUIMenuitem checkmarkItemWithTitle: OBL(@"Interactive", @"Interactive send mode") shortcut: nil userData: MenuSendModeInteractive checked: YES],
				_sendModeMenuitems[1] = [MUIMenuitem checkmarkItemWithTitle: OBL(@"Line Buffered", @"Line buffered send mode") shortcut: nil userData: MenuSendModeLineBuffered checked: NO],
			nil],
			[MUIMenuitem barItem],
			_termEmulationModeMenu = [MUIMenu menuWithTitle: OBL(@"Terminal Emulation...", @"Menu for terminal emulation mode") objects:
				_termEmulationMenuitems[0] = [MUIMenuitem checkmarkItemWithTitle: OBL(@"ANSI X3.64 1979", @"ANSI terminal emulation") shortcut: nil userData: MenuTerminalEmulation + MUIV_PowerTerm_Emulation_ANSI checked: NO],
				_termEmulationMenuitems[1] = [MUIMenuitem checkmarkItemWithTitle: OBL(@"DEC VT100", @"VT100 terminal emulation") shortcut: nil userData: MenuTerminalEmulation + MUIV_PowerTerm_Emulation_VT100 checked: NO],
				_termEmulationMenuitems[2] = [MUIMenuitem checkmarkItemWithTitle: OBL(@"TTY", @"TTY terminal emulation") shortcut: nil userData: MenuTerminalEmulation + MUIV_PowerTerm_Emulation_TTY checked: YES],
				_termEmulationMenuitems[3] = [MUIMenuitem checkmarkItemWithTitle: OBL(@"XTerm", @"XTerm terminal emulation") shortcut: nil userData: MenuTerminalEmulation + MUIV_PowerTerm_Emulation_XTerm checked: NO],
				_termEmulationMenuitems[4] = [MUIMenuitem checkmarkItemWithTitle: OBL(@"Amiga", @"Amiga con-handler emulation") shortcut: nil userData: MenuTerminalEmulation + MUIV_PowerTerm_Emulation_Amiga checked: NO],
			nil],
			_CRAsCRLFMenuitem = [MUIMenuitem checkmarkItemWithTitle: OBL(@"Interpret CR as CRLF", @"End line interpretation option") shortcut: nil userData: MenuCRAsCRLF checked: YES],
			_LFAsCRLFMenuitem = [MUIMenuitem checkmarkItemWithTitle: OBL(@"Interpret LF as CRLF", @"End line interpretation option") shortcut: nil userData: MenuLFAsCRLF checked: NO],
			[MUIMenuitem barItem],
			[MUIMenuitem itemWithTitle: OBL(@"MUI...", @"Menu MUI Preferences") shortcut: nil userData: MenuMUIPreferences],
		nil],
	nil];

	_termResetMenuitem.enabled = NO;
	_disconnectMenuitem.enabled = NO;

	return s;
}

-(VOID) setMenuAction: (ULONG)menuAction
{
	if (menuAction & MenuTerminalEmulation)
	{
		self.terminalEmulationMode = menuAction - MenuTerminalEmulation;
		return;
	}

	switch (menuAction)
	{
		case MenuNewWindow:
			[(Application *)self.applicationObject openNewTerminalWindow];
		break;

		case MenuLoadConfigFrom:
			[self loadConfigurationFromFile];
		break;

		case MenuSaveCurrentConfigAs:
			[self saveCurrentConfigurationToFile];
		break;

		case MenuTermReset:
			[_term reset];
		break;

		case MenuDisconnect:
			[self disconnect];
		break;

		case MenuMUIPreferences:
			[self.applicationObject openConfigWindow: 0 classid: nil];
		break;

		case MenuAbout:
			[(Application *)self.applicationObject about];
		break;

		case MenuAboutMUI:
			[self.applicationObject aboutMUI: self];
		break;

		case MenuQuit:
			[self.applicationObject quit];
		break;

		case MenuLocalEchoOff:
		case MenuLocalEchoBeforeSend:
		case MenuLocalEchoAfterSend:
			self.localEchoMode = menuAction;
		break;

		case MenuSendModeInteractive:
		case MenuSendModeLineBuffered:
			self.sendMode = menuAction;
		break;

		case MenuCRAsCRLF:
			_term.cRasCRLF = _CRAsCRLFMenuitem.checked;
		break;

		case MenuLFAsCRLF:
			_term.lFasCRLF = _LFAsCRLFMenuitem.checked;
		break;
	}
}

-(OBDictionary *) currentConfiguration
{
	return [OBDictionary dictionaryWithObjectsAndKeys:
		[_devicesCycle.entries objectAtIndex: _devicesCycle.active], @"device-name",
		[OBNumber numberWithUnsignedLong: _unitString.integer], @"device-unit",
		[BaudRateOptions objectAtIndex: _baudRateCycle.active], @"baud-rate",
		[DataBitsOptions objectAtIndex: _dataBitsCycle.active], @"data-bits",
		[OBNumber numberWithUnsignedLong: _parityCycle.active], @"parity",
		[StopBitsOptions objectAtIndex: _stopBitsCycle.active], @"stop-bits",
		[OBNumber numberWithBool: _xFlowCheckmark.selected], @"xon-xoff",
		[OBNumber numberWithBool: _eofModeCheckmark.selected], @"eof-mode",
		[OBNumber numberWithUnsignedLong: _localEchoMode], @"echo-mode",
		[OBNumber numberWithUnsignedLong: _sendMode], @"send-mode",
		[OBNumber numberWithUnsignedLong: _term.emulation], @"terminal-type",
		[OBNumber numberWithBool: _CRAsCRLFMenuitem.checked], @"cr-as-crlf",
		[OBNumber numberWithBool: _LFAsCRLFMenuitem.checked], @"lf-as-crlf",
		[CharsetOptions objectAtIndex: _charsetCycle.active], @"charset-mibenum",
	nil];
}

-(VOID) saveCurrentConfiguration
{
	Application *app = (Application *)self.applicationObject;

	app.lastConfiguration = self.currentConfiguration;
}

-(VOID) loadConfiguration: (OBDictionary *)config
{
	ULONG i;

	if (config == nil)
		return;

	i = [_devicesCycle.entries indexOfObject: [config objectForKey: @"device-name"]];
	if (i != OBNotFound)
		_devicesCycle.active = i;

	_unitString.integer = [[config objectForKey: @"device-unit"] unsignedLongValue];

	i = [_baudRateCycle.entries indexOfObject: [config objectForKey: @"baud-rate"]];
	if (i != OBNotFound)
		_baudRateCycle.active = i;

	i = [_dataBitsCycle.entries indexOfObject: [config objectForKey: @"data-bits"]];
	if (i != OBNotFound)
		_dataBitsCycle.active = i;

	i = [[config objectForKey: @"parity"] unsignedLongValue];
	if (_parityCycle.entries.count > i)
		_parityCycle.active = i;

	i = [_stopBitsCycle.entries indexOfObject: [config objectForKey: @"stop-bits"]];
	if (i != OBNotFound)
		_stopBitsCycle.active = i;

	_xFlowCheckmark.selected = [[config objectForKey: @"xon-xoff"] boolValue];
	_eofModeCheckmark.selected = [[config objectForKey: @"eof-mode"] boolValue];

	self.localEchoMode = [[config objectForKey: @"echo-mode"] unsignedLongValue];
	self.sendMode = [[config objectForKey: @"send-mode"] unsignedLongValue];
	self.terminalEmulationMode = [[config objectForKey: @"terminal-type"] unsignedLongValue];

	_CRAsCRLFMenuitem.checked = [[config objectForKey: @"cr-as-crlf"] boolValue];
	_LFAsCRLFMenuitem.checked = [[config objectForKey: @"lf-as-crlf"] boolValue];

	i = [CharsetOptions indexOfObject: [config objectForKey: @"charset-mibenum"]];
	if (i != OBNotFound)
		_charsetCycle.active = i;
}

-(VOID) saveCurrentConfigurationToFile
{
	OBJSONSerializer *serializer = [OBJSONSerializer serializer];
	OBData *data = [serializer serializeDictionary: self.currentConfiguration error: NULL];
	struct FileRequester *fReq = MUI_AllocAslRequestTags(ASL_FileRequest, TAG_END);
	BOOL fileSelected;

	if (!fReq)
		return;

	self.applicationObject.sleep = YES;

	fileSelected = MUI_AslRequestTags(fReq,
		ASLFR_Window, (IPTR)self.window,
		ASLFR_DoSaveMode, TRUE,
		ASLFR_PrivateIDCMP, TRUE,
		ASLFR_RejectIcons, TRUE,
		ASLFR_PopToFront, TRUE,
		ASLFR_Activate, TRUE,
		ASLFR_TitleText, (IPTR)[OBL(@"Save Current Configuration Profile As", @"ASL requester for saving configuration profile title") nativeCString],
		ASLFR_PositiveText, (IPTR)[OBL(@"Save", @"ASL requester for saving configuration profile positive text") nativeCString],
		ASLFR_InitialPattern, (IPTR)"#?",
		ASLFR_DoPatterns, TRUE,
	TAG_END);

	if (fileSelected)
	{
		struct DiskObject *icon = self.applicationObject.diskObject;
		OBString *drawer = [OBString stringWithCString: fReq->fr_Drawer encoding: MIBENUM_SYSTEM];
		OBString *file = [OBString stringWithCString: fReq->fr_File encoding: MIBENUM_SYSTEM];
		OBString *path;

		if (![file hasSuffix: @".determ"])
			file = [file stringByAppendingString: @".determ"];

		path = [drawer stringByAddingPathComponent: file];

		if (![data writeToFile: path])
		{
			MUIRequest *req = [MUIRequest requestWithTitle: OBL(@"Error", @"Requester title for error")
			  message: OBL(@"There was an error during file save operation.", @"File save error message")
			  buttons: [OBArray arrayWithObjects: OBL(@"_OK", @"Error requester confirmation button"), nil]];
			[req requestWithWindow: self];
		}

		if (icon)
		{
			UBYTE oldType = icon->do_Type;
			STRPTR *oldToolTypes = icon->do_ToolTypes;
			STRPTR oldDefaultTool = icon->do_DefaultTool;
			STRPTR newToolTypes[] = {
				"(CONNECT)",
				NULL,
			};

			icon->do_Type = WBPROJECT;
			icon->do_ToolTypes = newToolTypes;
			icon->do_DefaultTool = (STRPTR)[((Application *)self.applicationObject).executablePath nativeCString];

			if (!PutIconTags((CONST STRPTR)path.nativeCString, icon,
				ICONPUTA_PutDefaultType, WBPROJECT,
			TAG_END))
			{
				MUIRequest *req = [MUIRequest requestWithTitle: OBL(@"Error", @"Requester title for error")
				  message: OBL(@"There was an error during icon file save operation.", @"File save error message")
				  buttons: [OBArray arrayWithObjects: OBL(@"_OK", @"Error requester confirmation button"), nil]];
				[req requestWithWindow: self];
			}

			icon->do_ToolTypes = oldToolTypes;
			icon->do_DefaultTool = oldDefaultTool;
			icon->do_Type = oldType;
		}
	}

	self.applicationObject.sleep = NO;
	MUI_FreeAslRequest(fReq);
}

-(VOID) loadConfigurationFromFile
{
	struct FileRequester *fReq = MUI_AllocAslRequestTags(ASL_FileRequest, TAG_END);
	BOOL fileSelected;

	if (!fReq)
		return;

	self.applicationObject.sleep = YES;

	fileSelected = MUI_AslRequestTags(fReq,
		ASLFR_Window, (IPTR)self.window,
		ASLFR_DoSaveMode, FALSE,
		ASLFR_PrivateIDCMP, TRUE,
		ASLFR_RejectIcons, TRUE,
		ASLFR_PopToFront, TRUE,
		ASLFR_Activate, TRUE,
		ASLFR_TitleText, (IPTR)[OBL(@"Load Configuration Profile From", @"ASL requester for loading configuration profile title") nativeCString],
		ASLFR_PositiveText, (IPTR)[OBL(@"Load", @"ASL requester for loading configuration profile positive text") nativeCString],
		ASLFR_InitialPattern, (IPTR)"#?",
		ASLFR_DoPatterns, TRUE,
	TAG_END);

	if (fileSelected)
	{
		OBString *drawer = [OBString stringWithCString: fReq->fr_Drawer encoding: MIBENUM_SYSTEM];
		OBString *file = [OBString stringWithCString: fReq->fr_File encoding: MIBENUM_SYSTEM];

		[self parseConfigurationFile: [drawer stringByAddingPathComponent: file]];
	}

	self.applicationObject.sleep = NO;
	MUI_FreeAslRequest(fReq);
}

-(VOID) parseConfigurationFile: (OBString *)path
{
	OBData *data = [OBData dataWithContentsOfFile: path];

	if (data)
	{
		OBJSONDeserializer *deserializer = [OBJSONDeserializer deserializer];
		OBDictionary *config = [deserializer deserializeAsDictionary: data error: NULL];

		if (config && [config isKindOfClass: [OBDictionary class]])
		{
			struct DiskObject *diskObject;

			[self loadConfiguration: config];

			if ((diskObject = GetDiskObject((STRPTR)path.nativeCString)))
			{
				if (FindToolType(diskObject->do_ToolTypes, "CONNECT"))
					[self connect];
				FreeDiskObject(diskObject);
			}
		}
		else
		{
			MUIRequest *req = [MUIRequest requestWithTitle: OBL(@"Error", @"Requester title for error")
			  message: OBL(@"Invalid file format.", @"File format error message")
			  buttons: [OBArray arrayWithObjects: OBL(@"_OK", @"Error requester confirmation button"), nil]];
			[req requestWithWindow: self];
		}
	}
	else
	{
		MUIRequest *req = [MUIRequest requestWithTitle: OBL(@"Error", @"Requester title for error")
		  message: OBL(@"File not found.", @"File load error message")
		  buttons: [OBArray arrayWithObjects: OBL(@"_OK", @"Error requester confirmation button"), nil]];
		[req requestWithWindow: self];
	}
}

-(VOID) setLocalEchoMode: (ULONG)value
{
	ULONG i;

	for (i = 0; i < sizeof(_localEchoMenuitems) / sizeof(*_localEchoMenuitems); i++)
		_localEchoMenuitems[i].checked = i + MenuLocalEchoOff == value;
	_localEchoMode = value;
}

-(VOID) setSendMode: (ULONG)value
{
	ULONG i;

	for (i = 0; i < sizeof(_sendModeMenuitems) / sizeof(*_sendModeMenuitems); i++)
		_sendModeMenuitems[i].checked = i + MenuSendModeInteractive == value;
	_sendMode = value;
}

-(VOID) setTerminalEmulationMode: (ULONG)value
{
	ULONG i;

	for (i = 0; i < sizeof(_termEmulationMenuitems) / sizeof(*_termEmulationMenuitems); i++)
		_termEmulationMenuitems[i].checked = i == value;
	_term.emulation = value;
}

@end
