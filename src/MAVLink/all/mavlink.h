#pragma once

// Compatibility forwarding header for build setups that resolve
// <all/mavlink.h> through src/MAVLink before the generated MAVLink include
// tree is searched.
#if __has_include(<mavlink/all/mavlink.h>)
#include <mavlink/all/mavlink.h>
#elif __has_include(<mavlink.h>)
#include <mavlink.h>
#else
#error "Unable to locate MAVLink dialect header"
#endif
