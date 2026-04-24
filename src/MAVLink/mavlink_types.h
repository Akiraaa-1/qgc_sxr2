#pragma once

// Compatibility forwarding header for include path orderings where src/MAVLink
// appears before the generated MAVLink include directory.
#if __has_include(<mavlink/mavlink_types.h>)
#include <mavlink/mavlink_types.h>
#else
#error "Unable to locate mavlink_types.h"
#endif
