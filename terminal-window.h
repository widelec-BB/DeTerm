/*
 * Copyright (c) 2018-2022 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#import <mui/MUIFramework.h>
#import "serial-device.h"

@interface TerminalWindow : MUIWindow <SerialDeviceDelegate>

-(VOID) loadConfiguration: (OBDictionary *)config;
-(VOID) disconnect;

@end
