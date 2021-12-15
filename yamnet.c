
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

#ifdef __EMUL__
#define pmsis_exit(n) exit(n)
#endif

#define  BUF_SIZE   15600
#ifndef STACK_SIZE
#define STACK_SIZE      1024
#endif

AT_HYPERFLASH_FS_EXT_ADDR_TYPE yamnet_L3_Flash = 0;
signed char Output_1[521];
#define __XSTR(__s) __STR(__s)
#define __STR(__s) #__s
char *FileName = __XSTR(AT_WAV);

static void cluster()
{

    header_struct header_info;
    if (ReadWavFromFile(FileName, Input_1, BUF_SIZE*sizeof(short), &header_info)){
        printf("Error reading wav file\n");
        pmsis_exit(1);
    }
    int num_samples = header_info.DataSize * 8 / (header_info.NumChannels * header_info.BitsPerSample);

    #ifdef PERF
    printf("Start timer\n");
    gap_cl_starttimer();
    gap_cl_resethwtimer();
    #endif

    yamnetCNN(Output_1);
    printf("Runner completed\n");
    int max_confidence = 0, max_idx = 0;
    for (int i=0; i<521; i++) {
        if (Output_1[i] > max_confidence) {
            max_confidence = Output_1[i];
            max_idx = i;
        }
    }
    printf("\n\nClass Predicted: %3d with confidence: %3d\n", max_idx, max_confidence);

}

int test_yamnet(void)
{
    printf("Entering main controller\n");

#ifndef __EMUL__
    /* Configure And open cluster. */
    struct pi_device cluster_dev;
    struct pi_cluster_conf cl_conf;
    cl_conf.id = 0;
    pi_open_from_conf(&cluster_dev, (void *) &cl_conf);
    if (pi_cluster_open(&cluster_dev))
    {
        printf("Cluster open failed !\n");
        pmsis_exit(-4);
    }
#endif
    // IMPORTANT - MUST BE CALLED AFTER THE CLUSTER IS SWITCHED ON!!!!
    printf("Constructor\n");
    int ConstructorErr = yamnetCNN_Construct();
    if (ConstructorErr)
    {
        printf("Graph constructor exited with error: %d\n(check the generated file yamnetKernels.c to see which memory have failed to be allocated)\n", ConstructorErr);
        pmsis_exit(-6);
    }


    printf("Call cluster\n");
#ifndef __EMUL__
    struct pi_cluster_task task = {0};
    task.entry = cluster;
    task.arg = NULL;
    task.stack_size = (unsigned int) STACK_SIZE;
    task.slave_stack_size = (unsigned int) SLAVE_STACK_SIZE;

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
        printf("%45s: Cycles: %10u (%%: %5.2f%%), Operations: %10u (%%: %5.2f%%), Operations/Cycle: %f\n", AT_GraphNodeNames[i], AT_GraphPerf[i], 100*((float) (AT_GraphPerf[i]) / TotalCycles), AT_GraphOperInfosNames[i], 100*((float) (AT_GraphOperInfosNames[i]) / TotalOper), ((float) AT_GraphOperInfosNames[i])/ AT_GraphPerf[i]);
      }
      printf("\n");
      printf("%45s: Cycles: %10u (%%:100.00%%), Operations: %10u (%%:100.00%%), Operations/Cycle: %f\n", "Total", TotalCycles, TotalOper, ((float) TotalOper)/ TotalCycles);
      printf("\n");
    }
#endif

    printf("Ended\n");
    pmsis_exit(0);
    return 0;
}

int main(int argc, char *argv[])
{
    printf("\n\n\t *** NNTOOL yamnet Example ***\n\n");
    #ifdef __EMUL__
    test_yamnet();
    #else
    return pmsis_kickoff((void *) test_yamnet);
    #endif
    return 0;
}
