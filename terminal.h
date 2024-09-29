/*
 * Copyright (c) 2018-2022 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#import <mui/MCCPowerTerm.h>
#import <mui/PowerTerm_mcc.h>

typedef enum
{
	LineEndModeCRLF = 0,
	LineEndModeCR,
	LineEndModeLF,
} LineEndMode;

static inline OBString *LineEndModeToStr(LineEndMode mode)
{
	switch (mode)
	{
		case LineEndModeCRLF:
			return @"CRLF";
		case LineEndModeCR:
			return @"CR";
		case LineEndModeLF:
			return @"LF";
	}
}

static inline LineEndMode LineEndModeFromStr(OBString *s)
{
	if ([s compare: @"CRLF"] == OBSame)
		return LineEndModeCRLF;
	if ([s compare: @"CR"] == OBSame)
		return LineEndModeCR;
	if ([s compare: @"LF"] == OBSame)
		return LineEndModeLF;
	return -1;
}

@interface Terminal : MCCPowerTerm

@property (nonatomic) LineEndMode lineEndMode;

-(VOID) write: (OBData *)data encoding: (ULONG)characterEncoding;

@end
