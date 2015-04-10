# GNUstep makefile

-include config.make
include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECTS = \
	SOPE/NGCards \
	SOPE/GDLContentStore \
	SoObjects	\
	Tools		\
	Tests/Unit \
	OpenChange \
	ActiveSync

ifeq ($(daemon),yes)
SUBPROJECTS += Main
endif

ifeq ($(webui),yes)
SUBPROJECTS += UI
endif

include $(GNUSTEP_MAKEFILES)/aggregate.make
