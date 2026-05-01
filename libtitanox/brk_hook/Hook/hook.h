// Modified by Euclid Jan G.
// https://wsfteam.xyz/discord for femboys
#ifndef hook_h
#define hook_h

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>

bool hook(void *o[], void *n[], int c);
bool unhook(void *o[], int c);

#ifdef __cplusplus
}
#endif

#endif /* hook_h */
