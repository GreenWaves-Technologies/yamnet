NNTOOL=nntool
MODEL_SQ8=1
MODEL_POW2=1
MODEL_FP16=1
# MODEL_NE16=1

MODEL_SUFFIX?=
MODEL_PREFIX?=yamnet
MODEL_PYTHON=python3
MODEL_BUILD=BUILD_MODEL$(MODEL_SUFFIX)

TRAINED_MODEL = models/yamnet.tflite

MODEL_EXPRESSIONS = 

NNTOOL_EXTRA_FLAGS += #--use_hard_sigmoid #-q


# Memory sizes for cluster L1, SoC L2 and Flash
ifeq '$(TARGET_CHIP_FAMILY)' 'GAP9'
	FREQ_CL?=370
	FREQ_FC?=370
	FREQ_PE?=370
	TARGET_L1_SIZE = 128000
	TARGET_L2_SIZE = 1400000
	TARGET_L3_SIZE = 8000000
else
	TOTAL_STACK_SIZE = $(shell expr $(CLUSTER_STACK_SIZE) \+ $(CLUSTER_SLAVE_STACK_SIZE) \* 7)
	ifeq '$(TARGET_CHIP)' 'GAP8_V3'
		FREQ_CL?=175
	else
		FREQ_CL?=50
	endif
	FREQ_FC?=250
	FREQ_PE?=250
	TARGET_L1_SIZE = 64000
	TARGET_L2_SIZE = 400000
	TARGET_L3_SIZE = 8000000
endif

# Cluster stack size for master core and other cores
CLUSTER_STACK_SIZE=4096
CLUSTER_SLAVE_STACK_SIZE=1024
CLUSTER_NUM_CORES=8

ifeq ($(MODEL_NE16), 1)
	NNTOOL_SCRIPT = models/nntool_script_ne16
	MODEL_SUFFIX = _NE16
else
ifeq ($(MODEL_HWC), 1)
	NNTOOL_SCRIPT = models/nntool_script_hwc
	MODEL_SUFFIX = _HWC
else
	NNTOOL_SCRIPT = models/nntool_script
endif
endif

include $(RULES_DIR)/at_common_decl.mk
$(info GEN ... $(CNN_GEN))
