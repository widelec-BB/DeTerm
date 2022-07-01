/*
 * Copyright (c) 2018-2022 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#import <ob/OBFramework.h>

typedef BYTE SerialDeviceError;

@protocol SerialDeviceDelegate

-(VOID) receiveFromSerialDevice: (SerialDeviceError)err data: (OBData *)data;
-(VOID) writeResultFromSerialDevice: (SerialDeviceError)err data: (OBData *)data;

@end

typedef enum
{
	ParityNone = 0,
	ParityEven,
	ParityOdd,
} Parity;

@interface SerialDevice : OBObject <OBSignalHandlerDelegate>

+(OBArray *) availableDevices;
+(OBString *) errorMessage: (BYTE)serialDeviceError;

@property (nonatomic, readonly) OBString *name;
@property (nonatomic) id<SerialDeviceDelegate> delegate;

-(id) init: (OBString *)name unit: (ULONG)unit;
-(id) init: (OBString *)name unit: (ULONG)unit delegate: (id <SerialDeviceDelegate>)d;

-(SerialDeviceError) openWithBaudRate: (ULONG)bd dataBits: (UBYTE)db stopBits: (UBYTE)sb parity: (Parity)p xFlow: (BOOL)xFlow eofMode: (BOOL)eofMode;
-(VOID) write: (OBData *)data;

@end
