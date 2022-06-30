/*
 * Copyright (c) 2018-2022 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#import <mui/PowerTerm_mcc.h>
#import <proto/charsets.h>
#import <proto/intuition.h>
#import <clib/alib_protos.h>
#import <ob/OBFramework.h>

#import <string.h>
#import "globaldefines.h"
#import "application.h"
#import "terminal-window.h"

typedef enum
{
	SendModeInteractive = 0,
	SendModeLineBuffered,
} SendMode;

typedef enum
{
	MenuNewWindow = 0,
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
	__weak MUIString *_unitString;
	__weak MUICycle *_devicesCycle, *_baudRateCycle, *_dataBitsCycle, *_parityCycle, *_stopBitsCycle, *_charsetCycle;
	__weak MUICheckmark *_xFlowCheckmark, *_eofModeCheckmark;
	__weak MCCPowerTerm *_term;

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
		MCCPowerTerm *termobj = [[MCCPowerTerm alloc] init];

		if (termobj && (self = [super init]))
		{
			LONG i;
			MUIGroup *deviceConfigGroup;
			MUIButton *connectButton;
			MUICheckmark *xFlowCheckmark, *eofModeCheckmark;
			MUIText *labels[6];

			_term = termobj;
			_term.eatAllInput = YES;
			_term.outEnable = YES;
			_term.uTFEnable = YES;
			_term.localAlt = MUIV_PowerTerm_LocalAlt_Right;
			_term.destructiveBS = YES;
			_term.resizableHistory = YES;

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

			self.rootObject = [MUIGroup groupWithPages:
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
			nil];
			self.title = @APP_TITLE;
			self.menustrip = [self createMenustrip];

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
			_localEchoMode = MenuLocalEchoOff;
			_sendMode = MenuSendModeInteractive;
			_term.emulation = MUIV_PowerTerm_Emulation_TTY;
			_term.cRasCRLF = YES;

			_unitString.integer = 0;

			_xFlowCheckmark = xFlowCheckmark;
			_eofModeCheckmark = eofModeCheckmark;

			[connectButton notify: @selector(pressed) trigger: NO performSelector: @selector(connect) withTarget: self];
			[_term notify: @selector(outLen) performSelector: @selector(handleNewTermInput) withTarget: self];

			InstancesCounter++;
		}
	}

	return self;
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

	_serialDevice = [[SerialDevice alloc] init: deviceName unit: unit delegate: self];
	if (!_serialDevice)
		return;

	err = [_serialDevice openWithBaudRate: baudRate dataBits: dataBits stopBits: stopBits parity: parity xFlow: xFlow eofMode: eofMode];

	if (err != 0)
	{
		OBString *message = [SerialDevice errorMessage: err];
		MUIRequest *req = [MUIRequest requestWithTitle: OBL(@"Error", @"Requester title for error")
		   message: message buttons: [OBArray arrayWithObjects: OBL(@"_OK", @"Error requester confirmation button"), nil]];
		[req requestWithWindow: self];
		return;
	}

	((MUIGroup *)self.rootObject).activePage = 1;

	_termResetMenuitem.enabled = YES;
	_disconnectMenuitem.enabled = YES;
}

-(VOID) disconnect
{
	((MUIGroup *)self.rootObject).activePage = 0;

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
		[self writeToTerminal: data encoding: [[CharsetOptions objectAtIndex: _charsetCycle.active] unsignedLongValue]];
	}
	else
		[self displayErrorRequester: err];
}

-(VOID) writeResultFromSerialDevice: (SerialDeviceError)err data: (OBData *)data
{
	if (err == 0)
	{
		if (_localEchoMode == MenuLocalEchoAfterSend)
			[self writeToTerminal: data encoding: MIBENUM_UTF_8];
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
		[self writeToTerminal: [OBData dataWithBytes: _term.outPtr + nextEchoStart length: _term.outLen - nextEchoStart] encoding: MIBENUM_UTF_8];
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
			_termResetMenuitem = [MUIMenuitem itemWithTitle: OBL(@"Reset Terminal", @"Menu entry label") shortcut: @"z" userData: MenuTermReset],
			_disconnectMenuitem = [MUIMenuitem itemWithTitle: OBL(@"Disconnect", @"Menu entry label") shortcut: @"c" userData: MenuDisconnect],
			[MUIMenuitem barItem],
			[MUIMenuitem itemWithTitle: OBL(@"About...", @"Menu entry label") shortcut: OBL(@"?", @"Menu About entry shortcut") userData: MenuAbout],
			[MUIMenuitem itemWithTitle: OBL(@"About MUI...", @"Menu entry label") shortcut: nil userData: MenuAboutMUI],
			[MUIMenuitem barItem],
			[MUIMenuitem itemWithTitle: OBL(@"Quit", @"Menu quit") shortcut: OBL(@"Q", @"Menu quit shortcut") userData: MenuQuit],
		nil],
		[[MUIMenu alloc] initWithTitle: OBL(@"Preferences", @"Menu entry label for preferences") objects:
			_localEchoMenu = [MUIMenu menuWithTitle: OBL(@"Local echo mode...", @"Menu for local echo mode selection") objects:
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
	ULONG i;

	if (menuAction & MenuTerminalEmulation)
	{
		ULONG mode = menuAction - MenuTerminalEmulation;

		for (i = 0; i < sizeof(_termEmulationMenuitems) / sizeof(*_termEmulationMenuitems); i++)
			_termEmulationMenuitems[i].checked = NO;

		_term.emulation = mode;
		_termEmulationMenuitems[mode].checked = YES;

		return;
	}

	switch (menuAction)
	{
		case MenuNewWindow:
			[(Application *)self.applicationObject openNewTerminalWindow];
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
			for (i = 0; i < sizeof(_localEchoMenuitems) / sizeof(*_localEchoMenuitems); i++)
				_localEchoMenuitems[i].checked = i + MenuLocalEchoOff == menuAction;
			_localEchoMode = menuAction;
		break;

		case MenuSendModeInteractive:
		case MenuSendModeLineBuffered:
			for (i = 0; i < sizeof(_sendModeMenuitems) / sizeof(*_sendModeMenuitems); i++)
				_sendModeMenuitems[i].checked = i + MenuSendModeInteractive == menuAction;
			_sendMode = menuAction;
		break;

		case MenuCRAsCRLF:
			_term.cRasCRLF = _CRAsCRLFMenuitem.checked;
		break;

		case MenuLFAsCRLF:
			_term.lFasCRLF = _LFAsCRLFMenuitem.checked;
		break;
	}
}

-(VOID) writeToTerminal: (OBData *)data encoding: (ULONG)characterEncoding
{
	if (characterEncoding != MIBENUM_INVALID && characterEncoding != MIBENUM_UTF_8)
	{
		OBString *str = [OBString stringFromData: data encoding: characterEncoding];
		[_term writeUnicode: (APTR)str.cString length: str.length format: MUIV_PowerTerm_WriteUnicode_UTF8];
	}
	else
		[_term write: (APTR)data.bytes length: data.length];
}

@end
