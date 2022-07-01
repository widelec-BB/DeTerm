/*
 * Copyright (c) 2018-2022 Filip "widelec-BB" Maryjanski, BlaBla group.
 * All rights reserved.
 * Distributed under the terms of the MIT License.
 */

#if DEBUG
#include <clib/debug_protos.h>
#define tprintf(template, ...) KPrintF((CONST_STRPTR)APP_TITLE " " __FILE__ " %d: " template, __LINE__ , ##__VA_ARGS__)
#define ENTER(...) KPrintF((CONST_STRPTR)APP_TITLE " enters: %s\n", __PRETTY_FUNCTION__)
#define LEAVE(...) KPrintF((CONST_STRPTR)APP_TITLE " leaves: %s\n", __PRETTY_FUNCTION__)
#define LEAVE_ERROR(reason) KPrintF((CONST_STRPTR)APP_TITLE " leaves %s with ERROR!: %s\n", __PRETTY_FUNCTION__, reason)
#define strd(x)(((STRPTR)x) ? (STRPTR)(x) : (STRPTR)"NULL")
#else
#define tprintf(...)
#define ENTER(...)
#define LEAVE(...)
#define LEAVE_ERROR(...)
#define strd(x)
#endif

#define TO_STRING(x) #x
#define MACRO_TO_STRING(x) TO_STRING(x)

#define APP_TITLE          "DeTerm"
#define APP_AUTHOR         "Filip \"widelec-BB\" Maryjanski"

#define APP_CYEARS         "2018 - "__YEAR__
#define APP_VER_MAJOR      1
#define APP_VER_MINOR      1
#define APP_VER_NO         MACRO_TO_STRING(APP_VER_MAJOR)"."MACRO_TO_STRING(APP_VER_MINOR)
#define APP_COPYRIGHT      APP_CYEARS " " APP_AUTHOR
#define APP_VERSION        "$VER: " APP_TITLE " " APP_VER_NO " (" __APP_DATE__ ") (c) " APP_COPYRIGHT

#define APP_SCREEN_TITLE   APP_TITLE " " APP_VER_NO " " __APP_DATE__

#define MUI_IMAGE_FILE_STR(path) "\33I[4:" path ".mbr]"

#ifdef DEBUG
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
#else
static inline VOID DumpBinaryData(UBYTE *data, ULONG len)
{
	return;
}
#endif /* __DEBUG__ */
