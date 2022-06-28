#import <ob/OBFramework.h>

@protocol SerialDeviceDelegate

-(VOID) receiveFromSerialDevice: (OBData *)data;

@end

typedef enum
{
	ParityNone = 0,
	ParityEven,
	ParityOdd,
} Parity;

typedef BYTE SerialDeviceError;

@interface SerialDevice : OBObject <OBSignalHandlerDelegate>

+(OBArray *) availableDevices;
+(OBString *) errorMessage: (BYTE)serialDeviceError;

@property (nonatomic, readonly) OBString *name;
@property (nonatomic) id<SerialDeviceDelegate> delegate;

-(id) init: (OBString *)name unit: (ULONG)unit;
-(id) init: (OBString *)name unit: (ULONG)unit delegate: (id <SerialDeviceDelegate>)d;

-(SerialDeviceError) openWithBaudRate: (ULONG)bd dataBits: (UBYTE)db stopBits: (UBYTE)sb parity: (Parity)p;
-(SerialDeviceError) write: (OBData *)data;

@end
