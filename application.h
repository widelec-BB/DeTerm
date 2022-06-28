/*
 * Copyright (c) 2018 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#import <mui/MUIFramework.h>

@interface Application : MUIApplication <OBSignalHandlerDelegate>

@property (nonatomic) MCCPowerTerm *termobj;
@property (nonatomic) MUIGroup *buttonsgroup;

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
