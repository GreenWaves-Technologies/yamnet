# Copyright (C) 2017 GreenWaves Technologies
# All rights reserved.

# This software may be modified and distributed under the terms
# of the BSD license.  See the LICENSE file for details.

ifndef GAP_SDK_HOME
  $(error Source sourceme in gap_sdk first)
endif

ifneq '$(TARGET_CHIP_FAMILY)' 'GAP9'
  $(error This Project is only for GAP9)
endif

WAVFILE = $(CURDIR)/calibration_features/speech_whistling_cut.wav

include common.mk
include $(RULES_DIR)/at_common_decl.mk

io=host

RAM_FLASH_TYPE ?= HYPER
#PMSIS_OS=freertos

ifeq '$(RAM_FLASH_TYPE)' 'HYPER'
APP_CFLAGS += -DUSE_HYPER
MODEL_L3_EXEC=hram
MODEL_L3_CONST=hflash
else
APP_CFLAGS += -DUSE_SPI
CONFIG_SPIRAM = 1
MODEL_L3_EXEC=qspiram
MODEL_L3_CONST=qpsiflash
endif

include common/model_decl.mk

# pulpChip = GAP
# PULP_APP = $(MODEL_PREFIX)

APP = $(MODEL_PREFIX)
APP_SRCS += $(MODEL_PREFIX).c $(MODEL_GEN_C) $(MODEL_COMMON_SRCS) $(CNN_LIB) $(GAP_LIB_PATH)/wav_io/wavIO.c 

APP_CFLAGS  += -w -g -O3 -mno-memcpy -fno-tree-loop-distribute-patterns
APP_CFLAGS  += -I. -I$(MODEL_COMMON_INC) -I$(TILER_EMU_INC) -I$(TILER_INC) $(CNN_LIB_INCLUDE) -I$(MODEL_BUILD) -I$(GAP_SDK_HOME)/libs/gap_lib/include 
APP_CFLAGS  += -DPERF -DAT_MODEL_PREFIX=$(MODEL_PREFIX) $(MODEL_SIZE_CFLAGS)
APP_CFLAGS  += -DSTACK_SIZE=$(CLUSTER_STACK_SIZE) -DSLAVE_STACK_SIZE=$(CLUSTER_SLAVE_STACK_SIZE)
APP_CFLAGS  += -DAT_WAV=$(WAVFILE) -DF16_DSP_BFLOAT -DCI
APP_LDFLAGS	+= -lm

READFS_FILES=$(abspath $(MODEL_TENSORS))

# all depends on the model
all:: model

clean:: clean_model

include common/model_rules.mk
$(info APP_SRCS... $(APP_SRCS))
$(info APP_CFLAGS... $(APP_CFLAGS))
include $(RULES_DIR)/pmsis_rules.mk

