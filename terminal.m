#import <devices/rawkeycodes.h>
#import "globaldefines.h"
#import "terminal.h"

@implementation Terminal

-(id) init
{
	if ((self = [super init]))
	{
		self.handledEvents = IDCMP_RAWKEY;
		self.eventHandlerGUIMode = YES;
		self.eventHandlerPriority = 1;

		self.eatAllInput = YES;
		self.outEnable = YES;
		self.uTFEnable = YES;
		self.localAlt = MUIV_PowerTerm_LocalAlt_Right;
		self.destructiveBS = YES;
		self.resizableHistory = YES;
	}
	return self;
}

-(ULONG) handleEvent: (struct IntuiMessage *)imsg muikey: (LONG)muikey
{
	if (imsg && imsg->Class == IDCMP_RAWKEY)
	{
		switch (imsg->Code)
		{
			case RAWKEY_NM_WHEEL_UP:
				[super scroll: -1 mode: MUIV_PowerTerm_Scroll_Normal];
			break;

			case RAWKEY_NM_WHEEL_DOWN:
				[super scroll: 1 mode: MUIV_PowerTerm_Scroll_Normal];
			break;
		}
	}

	return [super handleEvent: imsg muikey: muikey];
}

-(VOID) write: (OBData *)data encoding: (ULONG)characterEncoding
{
	if (characterEncoding != MIBENUM_INVALID && characterEncoding != MIBENUM_UTF_8)
	{
		OBString *str = [OBString stringFromData: data encoding: characterEncoding];
		[super writeUnicode: (APTR)str.cString length: str.length format: MUIV_PowerTerm_WriteUnicode_UTF8];
	}
	else
		[super write: (APTR)data.bytes length: data.length];
}

@end
