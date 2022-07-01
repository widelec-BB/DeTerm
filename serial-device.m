/*
 * Copyright (c) 2018-2022 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#import <proto/exec.h>
#import <devices/serial.h>
#import <clib/alib_protos.h>
#import <proto/query.h>
#import <ob/OBDataMutable.h>
#import "globaldefines.h"
#import "serial-device.h"

@implementation SerialDevice
{
	OBString *_deviceName;
	ULONG _deviceUnit;

	id<SerialDeviceDelegate> _delegate;

	OBSignalHandler *_sigHandler;
	struct MsgPort *_rxPort;
	struct IOExtSer *_ioExtSerRead, *_ioExtSerWrite;

	UBYTE _buffer[1024];
	OBData *_writeData;
}

+(OBArray *) availableDevices
{
	APTR queryInfo = NULL;
	OBMutableArray *devices = [OBMutableArray arrayWithCapacity: 10];

	if ((QueryBase = OpenLibrary("query.library", 51)))
	{
		while ((queryInfo = QueryObtainTags(queryInfo,
			QUERYFINDATTR_TYPE, QUERYTYPE_DEVICE,
			QUERYFINDATTR_SUBTYPE, QUERYSUBTYPE_DEVICE,
			QUERYFINDATTR_CLASS, QUERYCLASS_SERIAL,
		TAG_DONE)))
		{
			STRPTR name;

			QueryGetAttr(queryInfo, &name, QUERYINFOATTR_NAME);

			[devices addObject: [OBString stringWithCString: name encoding: MIBENUM_SYSTEM]];
		}

		CloseLibrary(QueryBase);
	}

	[devices sortUsingSelector: @selector(compare:)];

	return devices;
}

+(OBString *) errorMessage: (BYTE)serialDeviceError
{
	OBString *message;

	switch (serialDeviceError)
	{
		case -1:
			message = OBL(@"Failed to open device.", @"Error message");
		break;

		case SerErr_DevBusy:
			message = OBL(@"Device is busy.", @"Error message");
		break;

		case SerErr_BaudMismatch:
			message = OBL(@"Invalid baud rate.", @"Error message");
		break;

		case SerErr_InvParam:
			message = OBL(@"Invalid device configuration.", @"Error message");
		break;

		case SerErr_ParityErr:
			message = OBL(@"Parity check failed.", @"Error message");
		break;

		default:
			message = OBL(@"Serial device error.", @"Error message");
	}

	return message;
}

@synthesize name = _deviceName;

-(id) init: (OBString *)name unit: (ULONG)unit
{
	if ((self = [super init]))
	{
		_deviceName = name;
		_deviceUnit = unit;

		if (![self setupSignalHandler])
			return nil;
	}
	return self;
}

-(id) init: (OBString *)name unit: (ULONG)unit delegate: (id<SerialDeviceDelegate>)d
{
	if ((self = [self init: name unit: unit]))
	{
		self.delegate = d;
	}
	return self;
}

-(VOID) dealloc
{
	[self cleanupSignalHandler];
}

-(id<SerialDeviceDelegate>) delegate
{
	return _delegate;
}

-(VOID) setDelegate: (id<SerialDeviceDelegate>)d
{
	if (_ioExtSerRead->IOSer.io_Device)
		WaitIO((struct IORequest *)_ioExtSerRead);

	_delegate = d;

	if (_ioExtSerRead->IOSer.io_Device)
		[self enqueueRead];
}

-(SerialDeviceError) openWithBaudRate: (ULONG)bd dataBits: (UBYTE)db stopBits: (UBYTE)sb parity: (Parity)p xFlow: (BOOL)xFlow eofMode: (BOOL)eofMode
{
	SerialDeviceError err;
	if(OpenDevice(_deviceName.cString, 0L, (struct IORequest *)_ioExtSerRead, 0) == 0)
	{
		_ioExtSerRead->io_Baud = bd;
		_ioExtSerRead->io_ReadLen = _ioExtSerRead->io_WriteLen = db;
		_ioExtSerRead->io_StopBits = sb;
		switch (p)
		{
			case ParityNone:
				_ioExtSerRead->io_SerFlags &= ~(SERF_PARTY_ON | SERF_PARTY_ODD);
			break;

			case ParityEven:
				_ioExtSerRead->io_SerFlags |= ~SERF_PARTY_ON;
			break;

			case ParityOdd:
				_ioExtSerRead->io_SerFlags |= ~SERF_PARTY_ODD;
			break;
		}

		if (xFlow)
			_ioExtSerRead->io_SerFlags &= ~SERF_XDISABLED;
		else
			_ioExtSerRead->io_SerFlags |= SERF_XDISABLED;

		if (eofMode)
			_ioExtSerRead->io_SerFlags |= SERF_EOFMODE;
		else
			_ioExtSerRead->io_SerFlags &= ~SERF_EOFMODE;

		_ioExtSerRead->IOSer.io_Command = SDCMD_SETPARAMS;
		if ((err = DoIO((struct IORequest *)_ioExtSerRead)) == 0)
		{
			CopyMem(_ioExtSerRead, _ioExtSerWrite, sizeof(struct IOExtSer));
			_ioExtSerWrite->IOSer.io_Command = CMD_INVALID;

			_ioExtSerWrite->IOSer.io_Command = CMD_CLEAR;
			DoIO((struct IORequest *)_ioExtSerWrite);

			if (self.delegate)
				[self enqueueRead];

			return 0;
		}

		AbortIO((struct IORequest *)_ioExtSerRead);
		WaitIO((struct IORequest *)_ioExtSerRead);
		CloseDevice((struct IORequest *)_ioExtSerRead);
		_ioExtSerRead->IOSer.io_Device = NULL;
		_ioExtSerRead->IOSer.io_Command = CMD_INVALID;

		return err;
	}
	return _ioExtSerRead->IOSer.io_Error;
}

-(VOID) enqueueRead
{
	_ioExtSerRead->IOSer.io_Length = 1;
	_ioExtSerRead->IOSer.io_Data = (APTR)_buffer;
	_ioExtSerRead->IOSer.io_Command = CMD_READ;
	SendIO((struct IORequest *)_ioExtSerRead);
}

-(SerialDeviceError) readInto: (OBMutableData *)data length: (ULONG)len
{
	SerialDeviceError err;

	do
	{
		_ioExtSerRead->IOSer.io_Length = len < sizeof(_buffer) ? len : sizeof(_buffer);
		_ioExtSerRead->IOSer.io_Data = (APTR)_buffer;
		_ioExtSerRead->IOSer.io_Command = CMD_READ;

		if((err = DoIO((struct IORequest *)_ioExtSerRead)) != 0)
			return err;

		[data appendBytes: _buffer length: _ioExtSerRead->IOSer.io_Actual];
		len -= _ioExtSerRead->IOSer.io_Actual;
	} while(len > 0);

	return 0;
}

-(VOID) write: (OBData *)data
{
	WaitIO((struct IORequest *)_ioExtSerWrite);

	_ioExtSerWrite->IOSer.io_Length = data.length;
	_ioExtSerWrite->IOSer.io_Data = (APTR)data.bytes;
	_ioExtSerWrite->IOSer.io_Command = CMD_WRITE;
	_ioExtSerWrite->IOSer.io_Flags |= IOF_QUICK;

	BeginIO((struct IORequest *)_ioExtSerWrite);

	if (_ioExtSerWrite->IOSer.io_Flags & IOF_QUICK)
	{
		if (self.delegate)
			[self.delegate writeResultFromSerialDevice: _ioExtSerWrite->IOSer.io_Error data: data];
	}
	else
		_writeData = data;
}

-(VOID) performWithSignalHandler: (OBSignalHandler *)handler
{
	struct Message *msg;
	while ((msg = GetMsg(_rxPort)))
	{
		if (msg == (struct Message *)_ioExtSerRead)
		{
			if (_ioExtSerRead->IOSer.io_Command != CMD_READ)
				return;

			if (self.delegate == nil)
				return;

			if (_ioExtSerRead->IOSer.io_Error != 0)
			{
				[self.delegate receiveFromSerialDevice: _ioExtSerRead->IOSer.io_Error data: nil];
				return;
			}

			if(_ioExtSerRead->IOSer.io_Actual > 0)
			{
				ULONG alreadyReceived = _ioExtSerRead->IOSer.io_Actual;

				_ioExtSerRead->IOSer.io_Command = SDCMD_QUERY;
				if (DoIO((struct IORequest *)_ioExtSerRead) == 0 && _ioExtSerRead->IOSer.io_Actual > 0)
				{
					SerialDeviceError err;
					OBMutableData *data = [OBMutableData dataWithCapacity: _ioExtSerRead->IOSer.io_Actual + alreadyReceived];

					[data appendBytes: _buffer length: alreadyReceived];

					err = [self readInto: data length: _ioExtSerRead->IOSer.io_Actual];
					[self.delegate receiveFromSerialDevice: err data: data];
				}
				else
				{
					OBData *data = [OBData dataWithBytes: _buffer length: 1];
					[self.delegate receiveFromSerialDevice: 0 data: data];
				}
			}

			[self enqueueRead];
		}
		else if(msg == (struct Message *)_ioExtSerWrite)
		{
			if (self.delegate)
				[self.delegate writeResultFromSerialDevice: _ioExtSerRead->IOSer.io_Error data: _writeData];
			_writeData = nil;
		}
	}
}

-(BOOL) setupSignalHandler
{
	ENTER();

	_rxPort = CreateMsgPort();
	if(!_rxPort)
	{
		LEAVE_ERROR("Failed to create MsgPort");
		return NO;
	}

	_ioExtSerRead = (struct IOExtSer*)CreateExtIO(_rxPort, sizeof(struct IOExtSer));
	if(!_ioExtSerRead)
	{
		LEAVE_ERROR("Failed to create io request (read)");
		return NO;
	}
	_ioExtSerRead->IOSer.io_Command = CMD_INVALID;

	_ioExtSerWrite = (struct IOExtSer*)CreateExtIO(_rxPort, sizeof(struct IOExtSer));
	if(!_ioExtSerWrite)
	{
		LEAVE_ERROR("Failed to create io request (write)");
		return NO;
	}
	_ioExtSerWrite->IOSer.io_Command = CMD_INVALID;

	_sigHandler = [[OBSignalHandler alloc] initWithSharedSignalBit:(LONG)_rxPort->mp_SigBit task:(APTR)NULL freeWhenDone:(BOOL)NO];
	if(!_sigHandler)
	{
		LEAVE_ERROR("Failed to create signal handler");
		return NO;
	}

	_sigHandler.delegate = self;
	[[OBRunLoop currentRunLoop] addSignalHandler: _sigHandler];

	LEAVE();
	return YES;
}

-(VOID) cleanupSignalHandler
{
	ENTER();

	[[OBRunLoop currentRunLoop] removeSignalHandler: _sigHandler];

	if (_ioExtSerWrite)
	{
		if (_ioExtSerWrite->IOSer.io_Command != CMD_INVALID)
		{
			AbortIO((struct IORequest *)_ioExtSerWrite);
			WaitIO((struct IORequest *)_ioExtSerWrite);
		}
		DeleteExtIO((struct IORequest *)_ioExtSerWrite);
	}

	if (_ioExtSerRead)
	{
		if (_ioExtSerRead->IOSer.io_Command != CMD_INVALID)
		{
			AbortIO((struct IORequest *)_ioExtSerRead);
			WaitIO((struct IORequest *)_ioExtSerRead);
		}
		if (_ioExtSerRead->IOSer.io_Device)
			CloseDevice((struct IORequest *)_ioExtSerRead);
		DeleteExtIO((struct IORequest *)_ioExtSerRead);
	}

	if(_rxPort)
	{
		while(GetMsg(_rxPort));
		DeleteMsgPort(_rxPort);
	}

	LEAVE();
}

@end
