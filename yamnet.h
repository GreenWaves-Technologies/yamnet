#ifndef __yamnet_H__
#define __yamnet_H__

#define __PREFIX(x) yamnet ## x

// Include basic GAP builtins defined in the Autotiler
#include "Gap.h"

#ifdef __EMUL__
#include <sys/types.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/param.h>
#include <string.h>
#endif

#include "../../power_meas_utils/measurments_utils.h"
extern AT_HYPERFLASH_FS_EXT_ADDR_TYPE yamnet_L3_Flash;
#endif