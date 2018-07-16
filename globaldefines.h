/*
 * Copyright (c) 2018 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#ifndef __GLOBAL_DEFINES_H__
#define __GLOBAL_DEFINES_H__

#ifdef __DEBUG__
#include <clib/debug_protos.h>
#define tprintf(template, ...) KPrintF((CONST_STRPTR)APP_NAME " " __FILE__ " %d: " template, __LINE__ , ##__VA_ARGS__)
#define ENTER(...) KPrintF((CONST_STRPTR)APP_NAME " enters: %s\n", __PRETTY_FUNCTION__)
#define LEAVE(...) KPrintF((CONST_STRPTR)APP_NAME " leaves: %s\n", __PRETTY_FUNCTION__)
#define LEAVE_ERROR(reason) KPrintF((CONST_STRPTR)APP_NAME " leaves %s with ERROR!: %s\n", __PRETTY_FUNCTION__, reason)
#define strd(x)(((STRPTR)x) ? (STRPTR)(x) : (STRPTR)"NULL") 
#else
#define tprintf(...)
#define ENTER(...)
#define LEAVE(...)
#define LEAVE_ERROR(...)
#define strd(x)
static inline VOID DumpBinaryData(UBYTE *data, ULONG len)
{
	return;
}
#endif

#define TO_STRING(x) #x
#define MACRO_TO_STRING(x) TO_STRING(x)

#define APP_DATE            "16.07.2018"
#define APP_AUTHOR          "Filip \"widelec\" Maryjañski"
#define APP_NAME            "DeTerm"
#define APP_CYEARS          "2018"
#define APP_BASE            "DETERM"
#define APP_DESC            GetString(MSG_APPLICATION_DESCRIPTION)
#define APP_VER_MAJOR       1
#define APP_VER_MINOR       0
#define APP_VER_NO          MACRO_TO_STRING(APP_VER_MAJOR)"."MACRO_TO_STRING(APP_VER_MINOR)
#define APP_COPYRIGHT       " (c) " APP_CYEARS " BlaBla group"
#define APP_VER             "$VER: " APP_NAME " " APP_VER_NO " " APP_DATE APP_COPYRIGHT
#define APP_SCREEN_TITLE    APP_NAME " " APP_VER_NO " " APP_DATE  

#define APP_ABOUT    "\33b%p\33n\n\t" APP_AUTHOR "\n\n"

#ifndef SERIALNAME
#define SERIALNAME "serial.device"
#endif

#define SERIAL_CH34X_DEVICE_NAME  "serialch34x.device"
#define SERIAL_PL2303_DEVICE_NAME "serialpl2303.device"

#ifdef __DEBUG__
#define _between(a,x,b) ((x)>=(a) && (x)<=(b))
#define is_visible_ascii(x) _between(32, x, 127) 

static inline VOID DumpBinaryData(UBYTE *data, ULONG len)
{
	ULONG i;
	ULONG pos = 0;

	KPrintF("ptr: %lp len: %lu\n", data, len);
	KPrintF("--------- packet dump start --------------\n\n");

	while(TRUE)
	{
		if(pos >= len)
			break;

		for(i = pos; i < pos + 8; i++)
		{
			if(i < len)
				KPrintF("%02lx ", *(data + i));
			else
				KPrintF("   ");
		}
		KPrintF(" ");

		for(i = pos + 8; i < pos + 16; i++)
		{
			if(i < len)
				KPrintF("%02lx ", *(data + i));
			else
				KPrintF("   ");
		}
		KPrintF(" ");

		for(i = pos; i < pos + 8; i++)
			KPrintF("%c ", i < len ? is_visible_ascii(*(data + i)) ? *(data + i) : '.' : ' ');

		KPrintF(" ");

		for(i = pos + 8; i < pos + 16; i++)
			KPrintF("%c ", i < len ? is_visible_ascii(*(data + i)) ? *(data + i) : '.' : ' ');
			
		KPrintF("\n");

		pos += 16;
	}

	KPrintF("\n");

	KPrintF("--------- packet dump end --------------\n");
}

#endif /* __DEBUG__ */

#endif
