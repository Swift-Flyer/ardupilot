# PX4 build is via external build system

ifneq ($(PX4_ROOT),)
$(error PX4_ROOT found in config.mk - Please see http://dev.ardupilot.com/wiki/git-submodules/)
endif

ifneq ($(NUTTX_SRC),)
$(error NUTTX_SRC found in config.mk - Please see http://dev.ardupilot.com/wiki/git-submodules/)
endif

ifneq ($(UAVCAN_DIR),)
$(error UAVCAN_DIR found in config.mk - Please see http://dev.ardupilot.com/wiki/git-submodules/)
endif

# these can be overridden in developer.mk
PX4FIRMWARE_DIRECTORY ?= $(SKETCHBOOK)/modules/PX4Firmware
PX4NUTTX_DIRECTORY ?= $(SKETCHBOOK)/modules/PX4NuttX
UAVCAN_DIRECTORY ?= $(SKETCHBOOK)/modules/uavcan

PX4_ROOT := $(shell cd $(PX4FIRMWARE_DIRECTORY) && pwd)
NUTTX_ROOT := $(shell cd $(PX4NUTTX_DIRECTORY) && pwd)
NUTTX_SRC := $(NUTTX_ROOT)/nuttx/
UAVCAN_DIR=$(shell cd $(UAVCAN_DIRECTORY) && pwd)/

# warn if user has old PX4Firmware or PX4NuttX trees
ifneq ($(wildcard $(SKETCHBOOK)/../PX4Firmware),)
$(warning *** You have an old PX4Firmware tree - see http://dev.ardupilot.com/wiki/git-submodules/)
endif
ifneq ($(wildcard $(SKETCHBOOK)/../PX4NuttX),)
$(warning *** You have an old PX4NuttX tree - see http://dev.ardupilot.com/wiki/git-submodules/)
endif
ifneq ($(wildcard $(SKETCHBOOK)/../uavcan),)
$(warning *** You have an old uavcan tree - see http://dev.ardupilot.com/wiki/git-submodules/)
endif

NUTTX_GIT_VERSION := $(shell cd $(NUTTX_SRC) && git rev-parse HEAD | cut -c1-8)
PX4_GIT_VERSION   := $(shell cd $(PX4_ROOT) && git rev-parse HEAD | cut -c1-8)

EXTRAFLAGS += -DNUTTX_GIT_VERSION="\"$(NUTTX_GIT_VERSION)\""
EXTRAFLAGS += -DPX4_GIT_VERSION="\"$(PX4_GIT_VERSION)\""
EXTRAFLAGS += -DUAVCAN=1

# we have different config files for F4BY
F4BY_CONFIG_FILE=$(MK_DIR)/F4BY/config_f4by_APM.mk


SKETCHFLAGS=$(SKETCHLIBINCLUDES) -DARDUPILOT_BUILD -DTESTS_MATHLIB_DISABLE -DCONFIG_HAL_BOARD=HAL_BOARD_F4BY -DSKETCHNAME="\\\"$(SKETCH)\\\"" -DSKETCH_MAIN=ArduPilot_main -DAPM_BUILD_DIRECTORY=APM_BUILD_$(SKETCH)

WARNFLAGS = -Werror -Wno-psabi -Wno-packed -Wno-error=double-promotion -Wno-error=unused-variable -Wno-error=reorder -Wno-error=float-equal -Wno-error=pmf-conversions -Wno-error=missing-declarations -Wno-error=unused-function

# avoid PX4 submodules
export GIT_SUBMODULES_ARE_EVIL = 1

PYTHONPATH=$(SKETCHBOOK)/mk/F4BY/Tools/genmsg/src:$(SKETCHBOOK)/mk/F4BY/Tools/gencpp/src
export PYTHONPATH

F4BY_MAKE = $(v) GIT_SUBMODULES_ARE_EVIL=1 ARDUPILOT_BUILD=1 make -C $(SKETCHBOOK) -f $(PX4_ROOT)/Makefile EXTRADEFINES="$(SKETCHFLAGS) $(WARNFLAGS) "'$(EXTRAFLAGS)' APM_MODULE_DIR=$(SKETCHBOOK) SKETCHBOOK=$(SKETCHBOOK) CCACHE=$(CCACHE) PX4_ROOT=$(PX4_ROOT) NUTTX_SRC=$(NUTTX_SRC) MAXOPTIMIZATION="-Os" UAVCAN_DIR=$(UAVCAN_DIR)
F4BY_MAKE_ARCHIVES = make -C $(PX4_ROOT) NUTTX_SRC=$(NUTTX_SRC) CCACHE=$(CCACHE) archives MAXOPTIMIZATION="-Os"

HASHADDER_FLAGS += --ardupilot "$(SKETCHBOOK)"

ifneq ($(wildcard $(PX4_ROOT)),)
HASHADDER_FLAGS += --f4by "$(PX4_ROOT)"
endif
ifneq ($(wildcard $(NUTTX_SRC)/..),)
HASHADDER_FLAGS += --nuttx "$(NUTTX_SRC)/.."
endif
HASHADDER_FLAGS += --uavcan "$(UAVCAN_DIR)"

.PHONY: module_mk
module_mk:
	$(v) echo "Building $(SKETCHBOOK)/module.mk"
	$(RULEHDR)
	$(v) echo "# Auto-generated file - do not edit" > $(SKETCHBOOK)/module.mk.new
	$(v) echo "MODULE_COMMAND = ArduPilot" >> $(SKETCHBOOK)/module.mk.new
	$(v) echo "SRCS = $(wildcard $(SRCROOT)/*.cpp) $(SKETCHLIBSRCSRELATIVE)" >> $(SKETCHBOOK)/module.mk.new
	$(v) echo "MODULE_STACKSIZE = 4096" >> $(SKETCHBOOK)/module.mk.new
	$(v) echo "EXTRACXXFLAGS = -Wframe-larger-than=1200" >> $(SKETCHBOOK)/module.mk.new
	$(v) cmp $(SKETCHBOOK)/module.mk $(SKETCHBOOK)/module.mk.new 2>/dev/null || mv $(SKETCHBOOK)/module.mk.new $(SKETCHBOOK)/module.mk
	$(v) rm -f $(SKETCHBOOK)/module.mk.new



f4by: $(BUILDROOT)/make.flags CHECK_MODULES $(PX4_ROOT)/Archives/f4by.export $(SKETCHCPP) module_mk
	$(RULEHDR)
	$(v) rm -f $(PX4_ROOT)/makefiles/$(F4BY_CONFIG_FILE)
	$(v) cp $(PWD)/$(F4BY_CONFIG_FILE) $(PX4_ROOT)/makefiles/
	$(v) $(F4BY_MAKE) f4by_APM
	$(v) /bin/rm -f $(SKETCH)-f4by.px4
	$(v) cp $(PX4_ROOT)/Images/f4by_APM.px4 $(SKETCH)-f4by.px4
	$(v) $(SKETCHBOOK)/Tools/scripts/add_git_hashes.py $(HASHADDER_FLAGS) "$(SKETCH)-f4by.px4" "$(SKETCH)-f4by.px4"
	$(v) echo "F4BY $(SKETCH) Firmware is in $(SKETCH)-f4by.px4"

f4by: f4by

f4by-clean: clean CHECK_MODULES f4by-archives-clean f4by-cleandep
	$(v) /bin/rm -rf $(PX4_ROOT)/makefiles/build $(PX4_ROOT)/Build

f4by-cleandep: clean
	$(v) find $(PX4_ROOT)/Build -type f -name '*.d' | xargs rm -f
	$(v) find $(SKETCHBOOK)/$(SKETCH) -type f -name '*.d' | xargs rm -f





f4by-upload: f4by
	$(RULEHDR)
	$(v) $(F4BY_MAKE) f4by_APM upload

f4by-upload: f4by-upload

f4by-archives-clean:
	$(v) /bin/rm -rf $(PX4_ROOT)/Archives






$(PX4_ROOT)/Archives/f4by.export:
	$(v) $(F4BY_MAKE_ARCHIVES) BOARDS="f4by"


f4by-archives:

	$(v) $(F4BY_MAKE_ARCHIVES) BOARDS="f4by "
