/*
 * Copyright (c) 2018-2022 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#import <mui/MUIFramework.h>

@interface Application : MUIApplication

-(VOID) run;
-(VOID) about;
-(VOID) closeWindow: (MUIWindow *)w;
-(VOID) openNewTerminalWindow;

@end
