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

@implementation TerminalWindow
{
	MUIString *_unitString;
	MUICycle *_devicesCycle, *_baudRateCycle, *_dataBitsCycle, *_parityCycle, *_stopBitsCycle, *_charsetCycle;
	MUICheckmark *_xFlowCheckmark, *_eofModeCheckmark;
	MCCPowerTerm *_term;

	SerialDevice *_serialDevice;
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
	ENTER();

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

	LEAVE();
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

	_term.emulation = MUIV_PowerTerm_Emulation_TTY;

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
}

-(VOID) disconnect
{
	((MUIGroup *)self.rootObject).activePage = 0;
	[_term reset];
	_serialDevice = nil;
}

-(VOID) receiveFromSerialDevice: (SerialDeviceError)err data: (OBData *)data
{
	if (err == 0)
	{
		ULONG characterEncoding = [[CharsetOptions objectAtIndex: _charsetCycle.active] unsignedLongValue];

		DumpBinaryData((UBYTE *)data.bytes, data.length);

		if (characterEncoding != MIBENUM_INVALID)
		{
			OBString *str = [OBString stringFromData: data encoding: characterEncoding];
			DumpBinaryData((UBYTE *)str.cString, strlen(str.cString));
			[_term writeUnicode: (APTR)str.cString length: str.length format: MUIV_PowerTerm_WriteUnicode_UTF8];
		}
		else
			[_term write: (APTR)data.bytes length: data.length];
	}
	else
		[self displayErrorRequester: err];
}

-(VOID) writeResultFromSerialDevice: (SerialDeviceError)err data: (OBData *)data
{
	if (err == 0)
	{

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
	OBData *data = [OBData dataWithBytes: _term.outPtr length: _term.outLen];

	[_serialDevice write: data];
	[_term outFlush];
}

@end
