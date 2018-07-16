/*
 * Copyright (c) 2018 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#import <mui/MUIFramework.h>

@interface Application : MUIApplication <OBSignalHandlerDelegate>
{
	MCCPowerTerm *_termobj;
	struct MsgPort *_rxPort;
	struct IOExtSer *_ioExtSer;
	OBSignalHandler *_sigHandler;
	UBYTE _buffer[128];
	ULONG _bufferPos;
	UBYTE _readByte;
	MUIGroup *_buttonsgroup;
}
@property (readwrite, nonatomic, assign) MCCPowerTerm *termobj;
@property (nonatomic, assign) MUIGroup *buttonsgroup;

-(BOOL)setup;
-(void)cleanup;

-(BOOL)connectWith:(STRPTR)deviceName;

-(BOOL)connectCH34X;
-(BOOL)connectPL2303;
-(BOOL)connectRealSerial;

-(void)performWithSignalHandler:(OBSignalHandler*)handler;

-(void)addToTerm:(APTR)data length:(ULONG)length;
-(void)addToTerm:(APTR)data;

-(void)hideButtons;

@end
