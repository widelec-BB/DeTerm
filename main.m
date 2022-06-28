/*
 * Copyright (c) 2018-2022 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#import <proto/exec.h>
#import <mui/MUIFramework.h>
#import "globaldefines.h"
#import "application.h"

#if !__has_feature(objc_arc)
#error "Automatic Reference Counting is required"
#endif

int muiMain(int argc, char *argv[])
{
	Application *mapp = [[Application alloc] init];

	[mapp run];

	return RETURN_OK;
}
