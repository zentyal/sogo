# common make file for SoObject bundles

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../../Version

NEEDS_GUI=no
BUNDLE_EXTENSION     = .SOGo
BUNDLE_INSTALL_DIR   = $(SOGO_LIBDIR)
WOBUNDLE_EXTENSION   = $(BUNDLE_EXTENSION)
WOBUNDLE_INSTALL_DIR = $(BUNDLE_INSTALL_DIR)

# SYSTEM_LIB_DIR += -L/usr/local/lib -L/usr/lib

ADDITIONAL_INCLUDE_DIRS += \
	-I.. \
	-I../.. \
        -I../../SOPE

ADDITIONAL_LIB_DIRS += \
        -L../SOGo/SOGo.framework/Versions/Current/sogo/ -lSOGo \
	-L../../SOGo/$(GNUSTEP_OBJ_DIR)/ \
	-L../../SOPE/NGCards/$(GNUSTEP_OBJ_DIR)/ -lNGCards \
        -L../../SOPE/GDLContentStore/$(GNUSTEP_OBJ_DIR)/ -lGDLContentStore \
        -L/usr/local/lib \
        -Wl,-rpath,../SOGo/SOGo.framework/Versions/Current/sogo -Wl,-rpath,../../SOPE/NGCards/obj -Wl,-rpath,../../SOPE/GDLContentStore/obj

BUNDLE_LIBS += \
	-lGDLAccess				\
	-lNGObjWeb				\
	-lNGMime -lNGLdap			\
	-lNGStreams -lNGExtensions -lEOControl	\
	-lDOM -lSaxObjC -lSBJson

ADDITIONAL_BUNDLE_LIBS += $(BUNDLE_LIBS)
