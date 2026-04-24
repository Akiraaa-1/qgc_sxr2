#pragma once

// Compatibility forwarding header for tooling/build setups that still include
// the legacy top-level MAVLink header path.
#if __has_include(<mavlink/all/mavlink.h>)
#include <mavlink/all/mavlink.h>
#elif __has_include(<all/mavlink.h>)
#include <all/mavlink.h>
#else
#error "Unable to locate MAVLink dialect header"
#endif
