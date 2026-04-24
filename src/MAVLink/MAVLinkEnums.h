#pragma once

// Compatibility fallback for build environments where the generated
// build/MAVLinkEnums.h was not produced or is not visible on the include path.
//
// Fall back to the normal QGC MAVLink entry header so all MAVLink enums,
// structs, and helper APIs are brought in through a single consistent path.
#include "MAVLinkLib.h"
