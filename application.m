/*
 * Copyright (c) 2018 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#import <mui/PowerTerm_mcc.h>
#import <proto/exec.h>
#import <devices/serial.h>
#import <clib/alib_protos.h>
#import <proto/muimaster.h>
#import <ob/OBFramework.h>
#import "globaldefines.h"
#import "application.h"
#import "string.h"

@implementation Application

@synthesize termobj = _termobj;
@synthesize buttonsgroup = _buttonsgroup;

-(BOOL)setup
{
	ENTER();

	self->_rxPort = CreateMsgPort();

	if(!self->_rxPort)
	{
		LEAVE_ERROR("Failed to create MsgPort");
		return NO;
	}

	self->_ioExtSer = (struct IOExtSer*)CreateExtIO(self->_rxPort, sizeof(struct IOExtSer));

	if(!self->_ioExtSer)
	{
		LEAVE_ERROR("Failed to create io request");
		return NO;
	}

	self->_sigHandler = [[OBSignalHandler alloc] initWithSharedSignalBit:(LONG)self->_rxPort->mp_SigBit task:(APTR)NULL freeWhenDone:(BOOL)NO];

	if(!self->_sigHandler)
	{
		LEAVE_ERROR("Failed to create signal handler");
		return NO;
	}

	self->_sigHandler.delegate = self;

	LEAVE();
	return YES;
}

-(void)cleanup
{
	ENTER();

	[[OBRunLoop currentRunLoop] removeSignalHandler: self->_sigHandler];

	if(self->_ioExtSer)
	{
		if(self->_ioExtSer->IOSer.io_Command != CMD_INVALID)
			WaitIO((struct IORequest*)self->_ioExtSer);

		if(self->_ioExtSer->IOSer.io_Device)
			CloseDevice((struct IORequest*)self->_ioExtSer);

		DeleteExtIO((struct IORequest*)self->_ioExtSer);
	}

	if(self->_rxPort)
	{
		while(GetMsg(self->_rxPort));

		DeleteMsgPort(self->_rxPort);
	}

	[self->_sigHandler release];

	LEAVE();
}

-(BOOL)connectWith:(STRPTR)deviceName
{
	ENTER();

	if(!OpenDevice(deviceName, 0L, (struct IORequest*)self->_ioExtSer, 0))
	{
		self->_ioExtSer->io_StopBits = 1;
		self->_ioExtSer->io_ReadLen = self->_ioExtSer->io_WriteLen = 8;
		self->_ioExtSer->io_SerFlags &= ~SERF_PARTY_ON;
		self->_ioExtSer->io_SerFlags |= SERF_XDISABLED;
		self->_ioExtSer->io_Baud = 115200;

		self->_ioExtSer->IOSer.io_Command = SDCMD_SETPARAMS;

		DoIO((struct IORequest*)self->_ioExtSer);
		WaitIO((struct IORequest*)self->_ioExtSer);

		self->_ioExtSer->IOSer.io_Command = CMD_CLEAR;

		DoIO((struct IORequest*)self->_ioExtSer);
		WaitIO((struct IORequest*)self->_ioExtSer);

		[[OBRunLoop currentRunLoop] addSignalHandler: self->_sigHandler];

		self->_ioExtSer->IOSer.io_Length = 1;
		self->_ioExtSer->IOSer.io_Data = (APTR)&self->_readByte;
		self->_ioExtSer->IOSer.io_Command = CMD_READ;

		self->_bufferPos = 0;

		SendIO((struct IORequest*)self->_ioExtSer);
		[self addToTerm:"Successfully connected\r\n"];

		[self hideButtons];

		LEAVE();
		return (IPTR)TRUE;
	}
	else
		MUI_Request(NULL, NULL, 0, APP_NAME" Error", "*_OK", "Failed to open %s", (APTR)deviceName);

	LEAVE_ERROR("Failed to connect");
	return (IPTR)FALSE;
}

-(BOOL)connectCH34X
{
	return [self connectWith:SERIAL_CH34X_DEVICE_NAME];
}

-(BOOL)connectPL2303
{
	return [self connectWith:SERIAL_PL2303_DEVICE_NAME];
}

-(BOOL)connectRealSerial
{
	return [self connectWith:SERIALNAME];
}

-(void)performWithSignalHandler:(OBSignalHandler*)handler
{
	WaitIO((struct IORequest*)self->_ioExtSer);

	if(self->_ioExtSer->IOSer.io_Error == 0 && self->_ioExtSer->IOSer.io_Command == CMD_READ && self->_ioExtSer->IOSer.io_Actual == 1)
	{
		self->_buffer[self->_bufferPos++] = self->_readByte;

		if(self->_readByte == '\n' || self->_bufferPos == sizeof(self->_buffer))
		{
			DumpBinaryData(self->_buffer, self->_bufferPos);
			[self addToTerm: self->_buffer length: self->_bufferPos];
			self->_bufferPos = 0;
		}
	}

	SendIO((struct IORequest*)self->_ioExtSer);
}

-(void)addToTerm:(APTR)data length:(ULONG)length
{
	[self.termobj write:data length:length];
}

-(void)addToTerm:(APTR)data
{
	[self.termobj write:data length:strlen(data)];
}

-(void)hideButtons
{
	self->_buttonsgroup.showMe = FALSE;
}

@end
