# ============================================================================
# MAVLink Module
# MAVLink protocol implementation and communication handling
# ============================================================================

target_sources(${CMAKE_PROJECT_NAME}
    PRIVATE
        ImageProtocolManager.cc
        ImageProtocolManager.h
        MAVLinkFTP.cc
        MAVLinkFTP.h
        MAVLinkLib.h
        MAVLinkMessageType.h
        MAVLinkSigning.cc
        MAVLinkSigning.h
        MAVLinkSigningKeys.cc
        MAVLinkSigningKeys.h
        MAVLinkStreamConfig.cc
        MAVLinkStreamConfig.h
        QGCMAVLink.cc
        QGCMAVLink.h
        QGCMAVLinkTypes.h
        StatusTextHandler.cc
        StatusTextHandler.h
        SysStatusSensorInfo.cc
        SysStatusSensorInfo.h
)

target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

# ============================================================================
# MAVLink Protocol Library Integration
# ============================================================================

message(STATUS "QGC: Building MAVLink")

CPMAddPackage(
    NAME mavlink
    GIT_REPOSITORY ${QGC_MAVLINK_GIT_REPO}
    GIT_TAG ${QGC_MAVLINK_GIT_TAG}
    OPTIONS
        "MAVLINK_DIALECT ${QGC_MAVLINK_DIALECT}"
        "MAVLINK_VERSION ${QGC_MAVLINK_VERSION}"
)

set(mavlink_enum_root "")
set(mavlink_include_dirs "")

if(EXISTS "${mavlink_BINARY_DIR}/include/mavlink/${QGC_MAVLINK_DIALECT}/${QGC_MAVLINK_DIALECT}.h")
    list(APPEND mavlink_include_dirs
        "${mavlink_BINARY_DIR}/include"
        "${mavlink_BINARY_DIR}/include/mavlink"
        "${mavlink_BINARY_DIR}/include/mavlink/${QGC_MAVLINK_DIALECT}"
    )
    set(mavlink_enum_root "${mavlink_BINARY_DIR}/include/mavlink")
elseif(EXISTS "${mavlink_SOURCE_DIR}/${QGC_MAVLINK_DIALECT}/${QGC_MAVLINK_DIALECT}.h")
    list(APPEND mavlink_include_dirs
        "${mavlink_SOURCE_DIR}"
        "${mavlink_SOURCE_DIR}/${QGC_MAVLINK_DIALECT}"
    )
    set(mavlink_enum_root "${mavlink_SOURCE_DIR}")
else()
    message(FATAL_ERROR
        "QGC: Unable to locate MAVLink headers for dialect '${QGC_MAVLINK_DIALECT}' "
        "in '${mavlink_BINARY_DIR}' or '${mavlink_SOURCE_DIR}'"
    )
endif()

if(NOT TARGET mavlink)
    add_custom_target(mavlink)
endif()

add_dependencies(${CMAKE_PROJECT_NAME} mavlink)
if(TARGET ClusterModule)
    add_dependencies(ClusterModule mavlink)
endif()

target_include_directories(${CMAKE_PROJECT_NAME}
    BEFORE PRIVATE
        ${mavlink_include_dirs}
)

# Generate lightweight MAVLinkEnums.h (enum typedefs only, no message pack/unpack code)
find_package(Python3 REQUIRED COMPONENTS Interpreter)
set(MAVLINK_ENUMS_OUTPUT "${CMAKE_BINARY_DIR}/MAVLinkEnums.h")
add_custom_command(
    OUTPUT "${MAVLINK_ENUMS_OUTPUT}"
    COMMAND ${Python3_EXECUTABLE}
        "${CMAKE_SOURCE_DIR}/cmake/GenerateMAVLinkEnums.py"
        "${mavlink_enum_root}"
        "${MAVLINK_ENUMS_OUTPUT}"
    DEPENDS mavlink "${CMAKE_SOURCE_DIR}/cmake/GenerateMAVLinkEnums.py"
    COMMENT "Generating MAVLinkEnums.h from MAVLink dialect headers"
    VERBATIM
)
add_custom_target(mavlink_enums DEPENDS "${MAVLINK_ENUMS_OUTPUT}")
add_dependencies(${CMAKE_PROJECT_NAME} mavlink_enums)
if(TARGET ClusterModule)
    add_dependencies(ClusterModule mavlink_enums)
endif()

# Ensure AUTOMOC runs after MAVLinkEnums.h is generated
set_property(TARGET ${CMAKE_PROJECT_NAME} APPEND PROPERTY AUTOGEN_TARGET_DEPENDS mavlink_enums)
target_include_directories(${CMAKE_PROJECT_NAME} BEFORE PRIVATE "${CMAKE_BINARY_DIR}")

# ----------------------------------------------------------------------------
# LibEvents - MAVLink event handling
# ----------------------------------------------------------------------------
add_subdirectory(LibEvents)
