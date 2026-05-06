# ============================================================================
# Cluster Module
# Independent cluster workspace state and adapter scaffolding
# ============================================================================

qt_add_library(ClusterModule STATIC)

qt_add_qml_module(ClusterModule
    URI QGroundControl.Cluster
    VERSION 1.0
    SOURCES
        ClusterManager.cc
        ClusterManager.h
        SwarmOperationAckHandler.cc
        SwarmOperationAckHandler.h
        SwarmFormationOverlayController.cc
        SwarmFormationOverlayController.h
        SwarmCommandBridge.cc
        SwarmCommandBridge.h
        SwarmUiAssignmentController.cc
        SwarmUiAssignmentController.h
        SwarmUiCommandController.cc
        SwarmUiCommandController.h
        SwarmUiSharedState.cc
        SwarmUiSharedState.h
    NO_PLUGIN
)

if(TARGET libevents)
    target_link_libraries(ClusterModule PRIVATE libevents)
endif()

target_include_directories(ClusterModule
    BEFORE PRIVATE
        ${CMAKE_BINARY_DIR}
        ${CMAKE_BINARY_DIR}/_deps/mavlink-build/include
        ${CMAKE_BINARY_DIR}/_deps/mavlink-build/include/mavlink
        ${CMAKE_BINARY_DIR}/_deps/mavlink-build/include/mavlink/${QGC_MAVLINK_DIALECT}
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/../Comms
        ${CMAKE_CURRENT_SOURCE_DIR}/../FactSystem
        ${CMAKE_CURRENT_SOURCE_DIR}/../MAVLink
        ${CMAKE_CURRENT_SOURCE_DIR}/../MAVLink/LibEvents
        ${CMAKE_CURRENT_SOURCE_DIR}/../QmlControls
        ${CMAKE_CURRENT_SOURCE_DIR}/../Utilities
        ${CMAKE_CURRENT_SOURCE_DIR}/../Vehicle
        ${CMAKE_CURRENT_SOURCE_DIR}/../Vehicle/FactGroups
)

if(DEFINED CPM_PACKAGE_libevents_SOURCE_DIR)
    target_include_directories(ClusterModule
        SYSTEM PRIVATE
            ${CPM_PACKAGE_libevents_SOURCE_DIR}/libs/cpp
    )
endif()
