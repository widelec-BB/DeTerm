# ENVIRONMENT #
TOOLS_PREFIX = ppc-morphos-

# MESSAGES #
COMPILE_FILE  = printf "\033[K\033[0;33mCompiling \033[1;33m$<\033[0;33m...\033[0m\n"
GENERATE_FILE = printf "\033[K\033[0;37mGenerating \033[1;37m$@\033[0;33m...\033[0m\n"
UPDATE_FILE   = printf "\033[K\033[0;36mUpdating \033[1;36m$@\033[0;33m...\033[0m\n"
TARGET_DONE   = printf "\033[K\033[0;32mTarget \"$@\" successfully done.\033[0m\n"
LINKING       = printf "\033[K\033[1;34mLinking project \"$@\"... \033[0m\n"

# VERSION DEFINES #
GITHASH = $(shell git log -1 --format=%H)
DATE    = $(shell date "+%d.%m.%Y")
YEAR    = $(shell date "+%Y")
CDVERSION = 1

# PROJECT #
OUTFILE = DeTerm
OBJDIR  = o/

# COMPILER #
CC     = $(TOOLS_PREFIX)clang
CWARNS = -Wall -Wno-pointer-sign -Werror
CDEFS  = "-D__APP_DATE__=\"$(DATE)\"" "-D__YEAR__=\"$(YEAR)\"" -DUSE_INLINE_STDARG
CFLAGS = -noixemul -fobjc-runtime=objfw -fobjc-arc -fconstant-string-class=OBConstantString -MD -MP
CLIBS  = -I/SDK/Frameworks/include

ifneq ($(GITHASH),)
CDEFS += "-D__GIT_HASH__=\"$(GITHASH)\""
endif

CDEFS_RELEASE  = $(CDEFS)
CFLAGS_RELEASE = $(CFLAGS) -O3
CLIBS_RELEASE  = $(CLIBS)

CDEFS_DEBUG  = $(CDEFS) -DDEBUG=1
CFLAGS_DEBUG = $(CFLAGS) -g -O0
CLIBS_DEBUG  = $(CLIBS)

# LINKER #
LD = $(TOOLS_PREFIX)clang

LWARNS =
LDEFS  =
LFLAGS = -noixemul
LIBS   = -lobjfwrt.library

LIBS_RELEASE = $(LIBS) -lmui.framework -lob-fw.framework
LIBS_DEBUG   = $(LIBS) -lmui_debug.framework -lob_debug-fw.framework -ldebug

# TARGETS #

# list of .PHONY targets
.PHONY: all release debug clean dump dist translations

# target 'all' (default target) call 'release'
all: release

# locales
TRANSLATIONS = $(wildcard locale/*.ct)
CATALOGS = $(TRANSLATIONS:%.ct=%.catalog)

locale/$(OUTFILE).cd: $(wildcard *.m)
	@$(GENERATE_FILE)
	@/SDK/Frameworks/bin/obcd -o locale/$(OUTFILE).cd --cdversion $(CDVERSION) *.m
$(TRANSLATIONS): %.ct: locale/$(OUTFILE).cd
	@$(UPDATE_FILE)
	@flexcat locale/$(OUTFILE).cd $@ NEWCTFILE $@
$(CATALOGS): %.catalog: %.ct
	@$(GENERATE_FILE)
	@flexcat locale/$(OUTFILE).cd $< CATALOG $@ FLUSH

# target 'translations' updates all *.ct files if locale/$(OUTFILE).cd has changed
translations: $(TRANSLATIONS)

# target 'clean' remove all generated files
clean:
	@-rm -rf $(OUTFILE) $(OUTFILE)_debug *.m.db.o *.m.db.d *.m.o *.m.d locale/$(OUTFILE).cd $(CATALOGS)
	@$(TARGET_DONE)

# taget 'dump' saves objdump in RAM:
dump:
	@-$(TOOLS_PREFIX)objdump -dC $(OUTFILE) >RAM:$(OUTFILE)-release.dmp
	@-$(TOOLS_PREFIX)objdump -dC $(OUTFILE)_debug >RAM:$(OUTFILE)-debug.dmp
	@$(TARGET_DONE)

# target 'dist' creates distributable package in RAM:
dist: release $(CATALOGS)
	@-delete RAM:$(OUTFILE) RAM:$(OUTFILE).lha ALL FORCE QUIET
	@mkdir RAM:$(OUTFILE)
	@copy $(OUTFILE) RAM:$(OUTFILE)/$(OUTFILE) >NIL:
	@strip --strip-unneeded --remove-section .comment RAM:$(OUTFILE)/$(OUTFILE) >NIL:
	@-copy $(OUTFILE).info RAM:$(OUTFILE)/$(OUTFILE).info >NIL:
	@copy docs/determ.readme RAM:$(OUTFILE)/$(OUTFILE).readme >NIL:
	@copy SYS:Prefs/Presets/Deficons/def_drawer.info RAM:$(OUTFILE).info
	@$(foreach LANG, $(CATALOGS:locale/%.catalog=%), mkdir -p RAM:$(OUTFILE)/catalogs/$(LANG) >NIL:)
	@$(foreach LANG, $(CATALOGS:locale/%.catalog=%), copy locale/$(LANG).catalog RAM:$(OUTFILE)/catalogs/$(LANG)/$(OUTFILE).catalog >NIL:)
	@MOSSYS:C/LHa a -r -a RAM:$(OUTFILE).lha RAM:$(OUTFILE) RAM:$(OUTFILE).info >NIL:
	@$(TARGET_DONE)

# create dependencies and compile targets for all *.m files
SOURCES      = $(wildcard *.m)
OBJS_RELEASE = $(SOURCES:%.m=%.m.o)
OBJS_DEBUG   = $(SOURCES:%.m=%.m.db.o)
DEPS_RELEASE = $(SOURCES:%.m=%.m.d)
DEPS_DEBUG   = $(SOURCES:%.m=%.m.db.d)

-include $(DEPS_RELEASE)
-include $(DEPS_DEBUG)

$(OBJS_RELEASE): %.m.o: %.m
	@$(COMPILE_FILE)
	@$(COMPILE) -c $< -o $@

$(OBJS_DEBUG): %.m.db.o: %.m
	@$(COMPILE_FILE)
	@$(COMPILE) -c $< -o $@

$(OUTFILE)_debug: $(OBJS_DEBUG)
	@$(LINKING)
	@$(LINK) -o $(OUTFILE)_debug

$(OUTFILE): $(OBJS_RELEASE)
	@$(LINKING)
	@$(LINK) -o $(OUTFILE)

# target 'release' builds project without any debug symbols, messages, etc.
release: COMPILE = $(CC) $(CWARNS) $(CDEFS_RELEASE) $(CLIBS_RELEASE) $(CFLAGS_RELEASE)
release: LINK = $(LD) $(LWARNS) $(LDEFS) $(LFLAGS) $(OBJS) $(LIBS_RELEASE)
release: OBJS = $(OBJS_RELEASE)
release: $(OBJS_RELEASE) $(OUTFILE)
	@$(TARGET_DONE)

# target 'debug' builds project with debug symbols, extra messages enabled, etc.
debug: COMPILE = $(CC) $(CWARNS) $(CDEFS_DEBUG) $(CLIBS_DEBUG) $(CFLAGS_DEBUG)
debug: LINK = $(LD) $(LWARNS) $(LDEFS) $(LFLAGS) $(OBJS) $(LIBS_DEBUG)
debug: OBJS = $(OBJS_DEBUG)
debug: $(OBJS_DEBUG) $(OUTFILE)_debug
	@$(TARGET_DONE)
