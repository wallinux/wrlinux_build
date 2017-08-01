# Example of a top Makefile for an integration setup
#

default: help

# Default settings
HOSTNAME 	?= $(shell hostname)
USER		?= $(shell whoami)
HOST_ARCH	?= $(shell uname -m)

# Optional configuration
-include hostconfig-$(HOSTNAME).mk
-include userconfig-$(USER).mk

TOP		:= $(shell pwd)

#
# These are variables you might want to override in either of the three
# configuration files above or on the command line
#
# Product definitions (where wrtools are installed for example)
WIND_INSTALL_BASE ?= $(TOP)/installs
WIND_VER	?= wrlinux_800
WIND_LX_HOME	?= $(WIND_INSTALL_BASE)/$(WIND_VER)

RCPL		?= auto
ifeq ($(RCPL),auto)
WIND_NAME	= $(WIND_VER).auto
RCPL_CONFIG	= $(RCPL)
else
WIND_NAME	= $(shell WIND_VER=$(WIND_VER); echo $${WIND_VER:0:12}).$(RCPL)
RCPL_CONFIG	= $(shell printf "%04d" $(RCPL))
endif

# Platform definitions
BSP		?= qemux86
ROOTFS		?= glibc_small
KERNEL		?= standard

GITROOT         = $(shell git rev-parse --show-toplevel)
OUTDIR		?= $(TOP)/out
BUILDDIR	?= $(OUTDIR)/build_$(BSP)_$(KERNEL)_$(ROOTFS)_$(WIND_NAME)
SSTATEDIR 	?= $(OUTDIR)/.sstate

# Define V=1 to echo everything
ifeq ($(V),)
	Q=@
endif

# Check for and generate stamps (NOTE: no ':') and a generic make target to
# force re-execution of target (eg make fs.force)
vpath % $(BUILDDIR)/.stamps
MKSTAMP	= $(Q)mkdir -p $(BUILDDIR)/.stamps ; touch $(BUILDDIR)/.stamps/$@
%.force:
	$(RM) $(BUILDDIR)/.stamps/$*
	$(MAKE) $*

ECHO		:= $(Q)echo -e
MKDIR		:= $(Q)mkdir -p
RM		:= $(Q)rm -f
MAKE		:= $(Q)make
WRL_CONFIGURE	:= $(WIND_LX_HOME)/wrlinux-8/wrlinux/configure

#EXTRA_CONFIG_OPTS += --enable-checkout-all-layers=yes
EXTRA_CONFIG_OPTS += --enable-buildhist=yes
EXTRA_CONFIG_OPTS += --enable-buildstats=yes

help::
	$(ECHO) "\nWIND_VER=$(WIND_VER) RCPL=$(RCPL) BSP=$(BSP) ROOTFS=$(ROOTFS)\n"
	$(ECHO) " all           - Build everything"
	$(ECHO) " kernel        - Build the kernel"
	$(ECHO) " bbs           - Start a subshell from which you can use bitbake"
	$(ECHO) " clean         - Remove everything (except installations)"
	$(ECHO) " distclean     - clean + remove sstate"
	$(ECHO)	" fs            - Build a filesystem (root image)"
	$(ECHO)	" sdk           - Build the SDK"

.PHONY: all fs sdk kernel clean distclean bbs
.FORCE:

all: fs sdk

fs: configure
	$(MAKE) -C $(BUILDDIR) $@

kernel: configure
	$(MAKE) -C $(BUILDDIR) virtual/kernel

kernel.clean: configure
	$(MAKE) -s -C $(BUILDDIR) bbc BBCMD="bitbake -c cleanall virtual/kernel"

sdk: configure
	$(MAKE) -C $(BUILDDIR) export-sdk

clean:
	$(RM) -r $(BUILDDIR)

distclean: sdk.clean clean
	$(RM) -r $(OUTDIR)

bbs: configure
	$(MAKE) -C $(BUILDDIR) $@

$(BUILDDIR) $(OUTDIR):
	$(MKDIR) $@

configure: $(WIND_LX_HOME) | $(BUILDDIR)
	cd $(BUILDDIR) ; $(WRL_CONFIGURE)		\
	  --enable-rootfs=$(ROOTFS)			\
	  --enable-kernel=$(KERNEL)			\
	  --enable-board=$(BSP)				\
	  --with-sstate-dir=$(SSTATEDIR)		\
	  --enable-reconfig				\
	  --with-rcpl-version=$(RCPL_CONFIG)		\
	  $(EXTRA_CONFIG_OPTS)
	$(MKSTAMP)

configure.help:
	$(WRL_CONFIGURE) --help | less

-include docker.mk
