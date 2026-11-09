/* For the demo recording only (docs/demo/record.sh): moves the wall clock
 * (CLOCK_REALTIME) by $CLOCK_SHIFT seconds, so the example week is shown
 * on the day it is written for. The monotonic clock, which paces frames,
 * is left alone. Loaded with LD_PRELOAD; never part of Shipinel. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdlib.h>
#include <time.h>

int clock_gettime(clockid_t clock, struct timespec *now) {
    static int (*real)(clockid_t, struct timespec *) = NULL;
    if (real == NULL) {
        real = (int (*)(clockid_t, struct timespec *))dlsym(RTLD_NEXT, "clock_gettime");
    }
    const int result = real(clock, now);
    const char *shift = getenv("CLOCK_SHIFT");
    if (clock == CLOCK_REALTIME && shift != NULL) {
        now->tv_sec += atol(shift);
    }
    return result;
}
