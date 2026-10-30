/*
 * The platform header of the WAMR build. WAMR's CMake puts the platform directory on the include path;
 * scripts/vendor-wamr.mbtx rewrites each include of "platform_internal.h" to this file instead.
 */
#if defined(__APPLE__)
#include "core/shared/platform/darwin/platform_internal.h"
#elif defined(__linux__)
#include "core/shared/platform/linux/platform_internal.h"
#elif defined(_WIN32)
#include "core/shared/platform/windows/platform_internal.h"
#endif
