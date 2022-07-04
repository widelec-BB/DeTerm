/*
 * Copyright (c) 2018-2022 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#import <mui/MCCPowerTerm.h>
#import <mui/PowerTerm_mcc.h>

@interface Terminal : MCCPowerTerm

-(VOID) write: (OBData *)data encoding: (ULONG)characterEncoding;

@end
