if [ -z $GAP_SDK_HOME ]; then
	echo "Source the sdk before"
	exit 1
fi

LOGDIR=logs
mkdir -p $LOGDIR/
AT_LOG_CHECK=${GAP_SDK_HOME}/nn_menu/power_meas_utils/check_at_model.py
OUT_LOG_CHECK=${GAP_SDK_HOME}/nn_menu/power_meas_utils/check_run.py
PICO_MEAS_SCRIPT=${GAP_SDK_HOME}/nn_menu/power_meas_utils/ps4444Measure.py
LOG_TO_CSV=${GAP_SDK_HOME}/nn_menu/power_meas_utils/log_to_csv.py

##########################################
MODES=('CHW' 'NE16' 'HWC')

export RAM_TYPE="OSPI"
export FLASH_TYPE="OSPI"
export PMSIS_OS=pulpos

set -e
python ${GAP_SDK_HOME}/nn_menu/power_meas_utils/check_pico.py
set +e

MODEL_NAME="YamNet"
for MODE in "${MODES[@]}"
do
	case $MODE in
		CHW)
			export MODEL_NE16=0
			export MODEL_FP16=0
			export MODEL_HWC=0
			;;
		NE16)
			export MODEL_NE16=1
			export MODEL_FP16=0
			export MODEL_HWC=0
			;;
		HWC)
			export MODEL_NE16=0
			export MODEL_FP16=0
			export MODEL_HWC=1
			;;
		FP16_CHW)
			export MODEL_NE16=0
			export MODEL_FP16=1
			export MODEL_HWC=0
			;;
		FP16_HWC)
			export MODEL_NE16=0
			export MODEL_FP16=1
			export MODEL_HWC=1
			;;
		*)
			echo "Mode $MODE not supported"
			exit 1
	esac

	MODEL_EXT="${MODEL_NAME}_${MODE}"

	echo "Running mode $MODE: GPIO_MEAS=1 MODEL_NE16=$MODEL_NE16 MODEL_FP16=$MODEL_FP16 MODEL_HWC=$MODEL_HWC RAM_TYPE=$RAM_TYPE FLASH_TYPE=$FLASH_TYPE"
	make clean_model model GPIO_MEAS=1 MODEL_NE16=$MODEL_NE16 MODEL_FP16=$MODEL_FP16 MODEL_HWC=$MODEL_HWC RAM_TYPE=$RAM_TYPE FLASH_TYPE=$FLASH_TYPE \
			> $LOGDIR/atmodel\_${MODEL_EXT}.txt
	# check if the autotiler found a solution
	python3 $AT_LOG_CHECK $LOGDIR/atmodel\_${MODEL_EXT}.txt
	if [ $? -eq "1" ]; then
		echo "Something went wrong with the model generation"
		continue
	fi

	# compile and flash
	make all -j GPIO_MEAS=1 MODEL_NE16=$MODEL_NE16 MODEL_FP16=$MODEL_FP16 MODEL_HWC=$MODEL_HWC RAM_TYPE=$RAM_TYPE FLASH_TYPE=$FLASH_TYPE

	for LOW_POWER_MODE in 0 1 ;
	do
		if [ $LOW_POWER_MODE -gt 0 ]; then
			FREQ=240
			export VOLTAGE=650
		else
			FREQ=370
			export VOLTAGE=800
		fi
		export FREQ_CL=$FREQ
		export FREQ_FC=$FREQ
		export FREQ_PE=$FREQ
		DVFS_FLAGS="FREQ_FC=$FREQ_FC FREQ_CL=$FREQ_CL FREQ_PE=$FREQ_PE VOLTAGE=$VOLTAGE"

		LOG_EXT="${MODEL_EXT}_${FREQ}_${VOLTAGE}"

		# generate the model
		echo "$LOG_EXT"
		touch yamnet.c


		echo "Running mode $MODE: GPIO_MEAS=1 MODEL_NE16=$MODEL_NE16 MODEL_FP16=$MODEL_FP16 MODEL_HWC=$MODEL_HWC RAM_TYPE=$RAM_TYPE FLASH_TYPE=$FLASH_TYPE $DVFS_FLAGS"
		# compile and run on board
		make build -j GPIO_MEAS=1 MODEL_NE16=$MODEL_NE16 MODEL_FP16=$MODEL_FP16 MODEL_HWC=$MODEL_HWC RAM_TYPE=$RAM_TYPE FLASH_TYPE=$FLASH_TYPE
		python3 $PICO_MEAS_SCRIPT $LOGDIR/power\_${LOG_EXT} & 
		make run GPIO_MEAS=1 MODEL_NE16=$MODEL_NE16 MODEL_FP16=$MODEL_FP16 MODEL_HWC=$MODEL_HWC RAM_TYPE=$RAM_TYPE FLASH_TYPE=$FLASH_TYPE \
				> $LOGDIR/output\_board\_log\_${LOG_EXT}.txt

		# check if any error in the grph constructor
		python3 $OUT_LOG_CHECK $LOGDIR/output\_board\_log\_${LOG_EXT}.txt
		if [ $? -eq "1" ]; then # kill the measurement job
			for job in `jobs -p`
			do
				echo $job
			    kill -9 $job
			done
			continue
		else # wait measurment job
			for job in `jobs -p`
			do
				echo $job
			    wait $job
			done
		fi

		python3 $LOG_TO_CSV $LOGDIR/power\_${LOG_EXT}.csv $LOGDIR/atmodel\_${MODEL_EXT}.txt $LOGDIR/log\_res.csv
	done
done
