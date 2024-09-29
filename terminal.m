/*
 * Copyright (c) 2018-2022 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#import <devices/rawkeycodes.h>
#import "globaldefines.h"
#import "terminal.h"

@implementation Terminal
{
	LineEndMode _lineEndMode;
	OBMutableData *_conversionBuffer, *_utfBuffer;
	ULONG _utfNeeded;
}

@synthesize lineEndMode = _lineEndMode;

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
		self.cRasCRLF = NO;
		self.lFasCRLF = NO;
		self->_lineEndMode = LineEndModeCRLF;
		self->_conversionBuffer = [OBMutableData dataWithCapacity: 1024];
		self->_utfBuffer = [OBMutableData dataWithCapacity: 4];
		self->_utfNeeded = 0;
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
	OBString *str;
	ENTER();

	if (self->_lineEndMode != LineEndModeCRLF) 
	{
		ULONG i;
		UBYTE replace = self->_lineEndMode == LineEndModeLF ? '\n' : '\r'; 

		self->_conversionBuffer.length = 0;

		for (i = 0; i < data.length; i++)
		{
			if (((UBYTE*)data.bytes)[i] == replace)
			{
				[self->_conversionBuffer appendBytes: "\r\n" length: 2];
			}
			else
			{
				[self->_conversionBuffer appendBytes: &data.bytes[i] length: 1]; 
			}
		}
		data = self->_conversionBuffer;
	}

	if (characterEncoding == MIBENUM_INVALID)
	{
		[super write: (APTR)data.bytes length: data.length];
		LEAVE();
		return;
	}

	if (characterEncoding == MIBENUM_UTF_8)
	{
		ULONG unicodeSafeCount = (ULONG)MAX((LONG)data.length - 4, 0);
		ULONG bytesLength = data.length, i;
		UBYTE *bytes = (UBYTE*)data.bytes;
		ULONG utfReminder = MIN(self->_utfNeeded, data.length);

		if (utfReminder > 0)
		{
			[self->_utfBuffer appendBytes: data.bytes length: utfReminder];
			bytes += utfReminder;
			bytesLength -= utfReminder;
			self->_utfNeeded -= utfReminder;
			if (self->_utfNeeded > 0)
			{
				LEAVE();
				return;
			}
			
			[super writeUnicode: (APTR)self->_utfBuffer.bytes length: self->_utfBuffer.length format: MUIV_PowerTerm_WriteUnicode_UTF8];
			self->_utfBuffer.length = 0;
		}

		for (i = unicodeSafeCount; i < bytesLength; i++)
		{
			if (bytes[i] >= 0x00 && bytes[i] <= 0x7f)
			{
				unicodeSafeCount += 1;
				continue;
			}

			if ((bytes[i] >= 0xf0 && bytes[i] <= 0xf4) && bytesLength - i < 4)
			{
				[self->_utfBuffer appendBytes: &bytes[i] length: bytesLength - i];
				self->_utfNeeded = 4 - bytesLength + i;
				break;
			}

			if ((bytes[i] >= 0xe0 && bytes[i] <= 0xef) && bytesLength - i < 3)
			{
				[self->_utfBuffer appendBytes: &bytes[i] length: bytesLength - i];
				self->_utfNeeded = 3 - bytesLength + i;
				break;
			}

			if ((bytes[i] >= 0xc2 && bytes[i] <= 0xdf) && bytesLength - i < 2)
			{
				[self->_utfBuffer appendBytes: &bytes[i] length: bytesLength - i];
				self->_utfNeeded = 2 - bytesLength + i;
				break;
			}

			unicodeSafeCount += 1;
		}

		if (unicodeSafeCount > 0) 
			[super writeUnicode: bytes length: unicodeSafeCount format: MUIV_PowerTerm_WriteUnicode_UTF8];
		LEAVE();
		return;
	}

	str = [OBString stringFromData: data encoding: characterEncoding];
	[super writeUnicode: (APTR)str.cString length: str.length format: MUIV_PowerTerm_WriteUnicode_UTF8];
	LEAVE();
}

@end
