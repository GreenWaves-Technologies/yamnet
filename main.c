
/*
 * Copyright (C) 2017 GreenWaves Technologies
 * All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the BSD license.  See the LICENSE file for details.
 *
 */


/* Autotiler includes. */
#include "yamnet.h"
#include "yamnetKernels.h"
#include "gaplib/wavIO.h"
#include "yamnet_class_map.h"

#ifdef __EMUL__
#define pmsis_exit(n) exit(n)
#endif

#define  BUF_SIZE   15600
#ifndef STACK_SIZE
#define STACK_SIZE      1024
#endif

AT_HYPERFLASH_FS_EXT_ADDR_TYPE yamnet_L3_Flash = 0;
AT_HYPERFLASH_FS_EXT_ADDR_TYPE yamnet_L3_PrivilegedFlash = 0;
unsigned char Output_1[521];
#define __XSTR(__s) __STR(__s)
#define __STR(__s) #__s
char *FileName = __XSTR(AT_WAV);
int max_confidence, max_idx;
static header_struct header_info;

static void cluster()
{
    int num_samples = header_info.DataSize * 8 / (header_info.NumChannels * header_info.BitsPerSample);

    #ifdef PERF
    printf("Start timer\n");
    gap_cl_starttimer();
    gap_cl_resethwtimer();
    #endif

    GPIO_HIGH();
    yamnetCNN(Output_1);
    GPIO_LOW();
    printf("Runner completed\n");
    max_confidence = 0, max_idx = 0;
    for (int i=0; i<521; i++) {
        if (Output_1[i] > max_confidence) {
            max_confidence = Output_1[i];
            max_idx = i;
        }
    }
    printf("\n\nClass Predicted: \"%s\" (%d) with confidence: %3d\n", class_titles[max_idx], max_idx, max_confidence);

}

int test_yamnet(void)
{
    printf("Entering main controller\n");

#ifndef __EMUL__
    OPEN_GPIO_MEAS();
    /* Configure And open cluster. */
    struct pi_device cluster_dev = {0};
    struct pi_cluster_conf cl_conf = {0};
    pi_cluster_conf_init(&cl_conf);
    cl_conf.id = 0;
    cl_conf.cc_stack_size = STACK_SIZE;
    pi_open_from_conf(&cluster_dev, (void *) &cl_conf);
    if (pi_cluster_open(&cluster_dev))
    {
        printf("Cluster open failed !\n");
        pmsis_exit(-4);
    }
    pi_freq_set(PI_FREQ_DOMAIN_FC, FREQ_FC*1000*1000);
    pi_freq_set(PI_FREQ_DOMAIN_CL, FREQ_CL*1000*1000);
    pi_freq_set(PI_FREQ_DOMAIN_PERIPH, FREQ_PE*1000*1000);
    printf("Set FC Frequency = %d MHz, CL Frequency = %d MHz, PERIIPH Frequency = %d MHz\n",
            pi_freq_get(PI_FREQ_DOMAIN_FC), pi_freq_get(PI_FREQ_DOMAIN_CL), pi_freq_get(PI_FREQ_DOMAIN_PERIPH));
    #ifdef VOLTAGE
    // pi_pmu_voltage_set(PI_PMU_VOLTAGE_DOMAIN_CHIP, VOLTAGE);
    // pi_pmu_voltage_set(PI_PMU_VOLTAGE_DOMAIN_CHIP, VOLTAGE);
    // printf("Voltage: %dmV\n", VOLTAGE);
    #endif
#endif
    // IMPORTANT - MUST BE CALLED AFTER THE CLUSTER IS SWITCHED ON!!!!
    printf("Constructor\n");
    int ConstructorErr = yamnetCNN_Construct();
    if (ConstructorErr)
    {
        printf("Graph constructor exited with error: %d\n(check the generated file yamnetKernels.c to see which memory have failed to be allocated)\n", ConstructorErr);
        return -6;
    }

    printf("Opening file: %s\n", FileName);
    if (ReadWavFromFile(FileName, Input_1, BUF_SIZE*sizeof(short), &header_info)){
        printf("Error reading wav file\n");
        pmsis_exit(1);
    }

    printf("Call cluster\n");
#ifndef __EMUL__
    struct pi_cluster_task task;
    pi_cluster_task(&task, (void (*)(void *))cluster, NULL);
    pi_cluster_task_stacks(&task, NULL, SLAVE_STACK_SIZE);
    pi_cluster_send_task_to_cl(&cluster_dev, &task);
#else
    cluster();
#endif

    yamnetCNN_Destruct();

#ifdef PERF
    {
      unsigned int TotalCycles = 0, TotalOper = 0;
      printf("\n");
      for (unsigned int i=0; i<(sizeof(AT_GraphPerf)/sizeof(unsigned int)); i++) {
        TotalCycles += AT_GraphPerf[i]; TotalOper += AT_GraphOperInfosNames[i];
      }
      for (unsigned int i=0; i<(sizeof(AT_GraphPerf)/sizeof(unsigned int)); i++) {
        printf("%45s: Cycles: %10u, Cyc%%: %5.1f%%, Operations: %10u, Op%%: %5.1f%%, Operations/Cycle: %f\n", AT_GraphNodeNames[i], AT_GraphPerf[i], 100*((float) (AT_GraphPerf[i]) / TotalCycles), AT_GraphOperInfosNames[i], 100*((float) (AT_GraphOperInfosNames[i]) / TotalOper), ((float) AT_GraphOperInfosNames[i])/ AT_GraphPerf[i]);
      }
      printf("\n");
      printf("%45s: Cycles: %10u, Cyc%%: 100.0%%, Operations: %10u, Op%%: 100.0%%, Operations/Cycle: %f\n", "Total", TotalCycles, TotalOper, ((float) TotalOper)/ TotalCycles);
      printf("\n");
    }
#endif
    #ifdef CI
    if(max_idx != 35 || max_confidence < 125){
        printf("Results Error...\n");
        return 1;
    }
    else
        printf("Correct Results!\n");
    #endif


    printf("Ended\n");
    return 0;
}

int main(int argc, char *argv[])
{
    printf("\n\n\t *** NNTOOL yamnet Example ***\n\n");
    test_yamnet();
    return 0;
}
