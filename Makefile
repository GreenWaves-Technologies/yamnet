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
HOMEDIR = $(CURDIR)
include common.mk
include common/model_decl.mk

io?=host

FLASH_TYPE ?= DEFAULT
RAM_TYPE   ?= DEFAULT

ifeq '$(FLASH_TYPE)' 'HYPER'
  MODEL_L3_FLASH=AT_MEM_L3_HFLASH
else ifeq '$(FLASH_TYPE)' 'MRAM'
  MODEL_L3_FLASH=AT_MEM_L3_MRAMFLASH
  READFS_FLASH = target/chip/soc/mram
else ifeq '$(FLASH_TYPE)' 'QSPI'
  MODEL_L3_FLASH=AT_MEM_L3_QSPIFLASH
  READFS_FLASH = target/board/devices/spiflash
else ifeq '$(FLASH_TYPE)' 'OSPI'
  MODEL_L3_FLASH=AT_MEM_L3_OSPIFLASH
  #READFS_FLASH = target/board/devices/ospiflash
else ifeq '$(FLASH_TYPE)' 'DEFAULT'
  MODEL_L3_FLASH=AT_MEM_L3_DEFAULTFLASH
endif

ifeq '$(RAM_TYPE)' 'HYPER'
  MODEL_L3_RAM=AT_MEM_L3_HRAM
else ifeq '$(RAM_TYPE)' 'QSPI'
  MODEL_L3_RAM=AT_MEM_L3_QSPIRAM
else ifeq '$(RAM_TYPE)' 'OSPI'
  MODEL_L3_RAM=AT_MEM_L3_OSPIRAM
else ifeq '$(RAM_TYPE)' 'DEFAULT'
  MODEL_L3_RAM=AT_MEM_L3_DEFAULTRAM
endif


ONLY_NN?=0
ifeq ($(ONLY_NN), 0)
  MAIN = main.c
  WAVFILE = $(CURDIR)/calibration_features/speech_whistling_cut.wav
else
  MAIN = yamnet.c
  ifneq '$(platform)' 'gvsoc'
  ifdef MEAS
  APP_CFLAGS += -DGPIO_MEAS
  endif
  endif
endif

APP = $(MODEL_PREFIX)
APP_SRCS += $(MAIN) $(MODEL_GEN_C) $(MODEL_COMMON_SRCS) $(CNN_LIB) $(GAP_LIB_PATH)/wav_io/wavIO.c 

APP_CFLAGS  += -w -g -O3 -mno-memcpy -fno-tree-loop-distribute-patterns
APP_CFLAGS  += -I. -I$(GAP_SDK_HOME)/utils/power_meas_utils -I$(MODEL_COMMON_INC) -I$(TILER_EMU_INC) -I$(TILER_INC) $(CNN_LIB_INCLUDE) -I$(MODEL_BUILD) -I$(GAP_SDK_HOME)/libs/gap_lib/include 
APP_CFLAGS  += -DPERF -DAT_MODEL_PREFIX=$(MODEL_PREFIX) $(MODEL_SIZE_CFLAGS)
APP_CFLAGS  += -DSTACK_SIZE=$(CLUSTER_STACK_SIZE) -DSLAVE_STACK_SIZE=$(CLUSTER_SLAVE_STACK_SIZE)
APP_CFLAGS  += -DAT_WAV=$(WAVFILE) -DF16_DSP_BFLOAT -DCI -DFREQ_FC=$(FREQ_FC) -DFREQ_CL=$(FREQ_CL) -DFREQ_PE=$(FREQ_PE)
APP_LDFLAGS	+= -lm
ifneq '$(platform)' 'gvsoc'
ifdef GPIO_MEAS
APP_CFLAGS += -DGPIO_MEAS
endif
VOLTAGE?=800
ifeq '$(PMSIS_OS)' 'pulpos'
  APP_CFLAGS += -DVOLTAGE=$(VOLTAGE)
endif
endif

ifeq ($(USE_PRIVILEGED_FLASH), 1)
MODEL_SEC_L3_FLASH=AT_MEM_L3_MRAMFLASH
else
MODEL_SEC_L3_FLASH=
endif

READFS_FILES=$(abspath $(MODEL_TENSORS))
ifneq ($(MODEL_SEC_L3_FLASH), )
  runner_args += --flash-property=$(CURDIR)/$(MODEL_SEC_TENSORS)@mram:readfs:files
endif
# build depends on the model
build:: model

clean:: clean_model

include common/model_rules.mk
$(info APP_SRCS... $(APP_SRCS))
$(info APP_CFLAGS... $(APP_CFLAGS))
include $(RULES_DIR)/pmsis_rules.mk

