#pragma once

// Compatibility forwarding header for tooling/build setups that resolve
// <mavlink/all/mavlink.h> through src/MAVLink before the generated include tree.
#if __has_include(<all/mavlink.h>)
#include <all/mavlink.h>
#elif __has_include(<mavlink.h>)
#include <mavlink.h>
#else
#error "Unable to locate MAVLink dialect header"
#endif
