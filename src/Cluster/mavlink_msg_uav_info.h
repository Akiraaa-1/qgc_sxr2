#pragma once

#include "MAVLinkMessageType.h"

#include <cstring>

#define MAVLINK_MSG_ID_UAV_INFO 12921
#define MAVLINK_MSG_ID_UAV_INFO_LEN 45
#define MAVLINK_MSG_ID_UAV_INFO_MIN_LEN 45
#define MAVLINK_MSG_ID_UAV_INFO_CRC 100

typedef struct __mavlink_uav_info_t {
    uint32_t mavid;
    uint32_t group_id;
    float lat;
    float lon;
    float yaw;
    float yaw_speed;
    float rel_alt;
    float vx;
    float vy;
    float vz;
    uint32_t land;
    uint8_t is_leader;
} mavlink_uav_info_t;

static inline uint32_t mavlink_msg_uav_info_get_mavid(const mavlink_message_t *msg)
{
    return _MAV_RETURN_uint32_t(msg, 0);
}

static inline uint32_t mavlink_msg_uav_info_get_group_id(const mavlink_message_t *msg)
{
    return _MAV_RETURN_uint32_t(msg, 4);
}

static inline float mavlink_msg_uav_info_get_lat(const mavlink_message_t *msg)
{
    return _MAV_RETURN_float(msg, 8);
}

static inline float mavlink_msg_uav_info_get_lon(const mavlink_message_t *msg)
{
    return _MAV_RETURN_float(msg, 12);
}

static inline float mavlink_msg_uav_info_get_yaw(const mavlink_message_t *msg)
{
    return _MAV_RETURN_float(msg, 16);
}

static inline float mavlink_msg_uav_info_get_yaw_speed(const mavlink_message_t *msg)
{
    return _MAV_RETURN_float(msg, 20);
}

static inline float mavlink_msg_uav_info_get_rel_alt(const mavlink_message_t *msg)
{
    return _MAV_RETURN_float(msg, 24);
}

static inline float mavlink_msg_uav_info_get_vx(const mavlink_message_t *msg)
{
    return _MAV_RETURN_float(msg, 28);
}

static inline float mavlink_msg_uav_info_get_vy(const mavlink_message_t *msg)
{
    return _MAV_RETURN_float(msg, 32);
}

static inline float mavlink_msg_uav_info_get_vz(const mavlink_message_t *msg)
{
    return _MAV_RETURN_float(msg, 36);
}

static inline uint32_t mavlink_msg_uav_info_get_land(const mavlink_message_t *msg)
{
    return _MAV_RETURN_uint32_t(msg, 40);
}

static inline uint8_t mavlink_msg_uav_info_get_is_leader(const mavlink_message_t *msg)
{
    return _MAV_RETURN_uint8_t(msg, 44);
}

static inline void mavlink_msg_uav_info_decode(const mavlink_message_t *msg, mavlink_uav_info_t *uavInfo)
{
    uavInfo->mavid = mavlink_msg_uav_info_get_mavid(msg);
    uavInfo->group_id = mavlink_msg_uav_info_get_group_id(msg);
    uavInfo->lat = mavlink_msg_uav_info_get_lat(msg);
    uavInfo->lon = mavlink_msg_uav_info_get_lon(msg);
    uavInfo->yaw = mavlink_msg_uav_info_get_yaw(msg);
    uavInfo->yaw_speed = mavlink_msg_uav_info_get_yaw_speed(msg);
    uavInfo->rel_alt = mavlink_msg_uav_info_get_rel_alt(msg);
    uavInfo->vx = mavlink_msg_uav_info_get_vx(msg);
    uavInfo->vy = mavlink_msg_uav_info_get_vy(msg);
    uavInfo->vz = mavlink_msg_uav_info_get_vz(msg);
    uavInfo->land = mavlink_msg_uav_info_get_land(msg);
    uavInfo->is_leader = mavlink_msg_uav_info_get_is_leader(msg);
}

static inline uint16_t mavlink_msg_uav_info_pack_chan(uint8_t system_id, uint8_t component_id, uint8_t chan,
                                                      mavlink_message_t *msg,
                                                      uint32_t mavid,
                                                      uint32_t group_id,
                                                      uint8_t is_leader,
                                                      float lat,
                                                      float lon,
                                                      float yaw,
                                                      float yaw_speed,
                                                      float rel_alt,
                                                      float vx,
                                                      float vy,
                                                      float vz,
                                                      uint32_t land)
{
    char buf[MAVLINK_MSG_ID_UAV_INFO_LEN];
    _mav_put_uint32_t(buf, 0, mavid);
    _mav_put_uint32_t(buf, 4, group_id);
    _mav_put_float(buf, 8, lat);
    _mav_put_float(buf, 12, lon);
    _mav_put_float(buf, 16, yaw);
    _mav_put_float(buf, 20, yaw_speed);
    _mav_put_float(buf, 24, rel_alt);
    _mav_put_float(buf, 28, vx);
    _mav_put_float(buf, 32, vy);
    _mav_put_float(buf, 36, vz);
    _mav_put_uint32_t(buf, 40, land);
    _mav_put_uint8_t(buf, 44, is_leader);

    memcpy(_MAV_PAYLOAD_NON_CONST(msg), buf, MAVLINK_MSG_ID_UAV_INFO_LEN);
    msg->msgid = MAVLINK_MSG_ID_UAV_INFO;
    return mavlink_finalize_message_chan(msg, system_id, component_id, chan,
                                         MAVLINK_MSG_ID_UAV_INFO_MIN_LEN,
                                         MAVLINK_MSG_ID_UAV_INFO_LEN,
                                         MAVLINK_MSG_ID_UAV_INFO_CRC);
}
