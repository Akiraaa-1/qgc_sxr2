#pragma once

#include "MAVLinkMessageType.h"

#include <cstring>

#define MAVLINK_MSG_ID_SWARM_START_FLAG 12923
#define MAVLINK_MSG_ID_SWARM_START_FLAG_LEN 5
#define MAVLINK_MSG_ID_SWARM_START_FLAG_MIN_LEN 5
#define MAVLINK_MSG_ID_SWARM_START_FLAG_CRC 125

static inline uint16_t mavlink_msg_swarm_start_flag_pack_chan(uint8_t system_id, uint8_t component_id, uint8_t chan,
                                                              mavlink_message_t *msg,
                                                              uint8_t start_swarm_auto,
                                                              uint8_t start_swarm,
                                                              uint8_t stop_swarm,
                                                              uint8_t pause_swarm,
                                                              uint8_t continue_swarm)
{
    char buf[MAVLINK_MSG_ID_SWARM_START_FLAG_LEN];
    _mav_put_uint8_t(buf, 0, start_swarm_auto);
    _mav_put_uint8_t(buf, 1, start_swarm);
    _mav_put_uint8_t(buf, 2, stop_swarm);
    _mav_put_uint8_t(buf, 3, pause_swarm);
    _mav_put_uint8_t(buf, 4, continue_swarm);

    memcpy(_MAV_PAYLOAD_NON_CONST(msg), buf, MAVLINK_MSG_ID_SWARM_START_FLAG_LEN);
    msg->msgid = MAVLINK_MSG_ID_SWARM_START_FLAG;
    return mavlink_finalize_message_chan(msg, system_id, component_id, chan,
                                         MAVLINK_MSG_ID_SWARM_START_FLAG_MIN_LEN,
                                         MAVLINK_MSG_ID_SWARM_START_FLAG_LEN,
                                         MAVLINK_MSG_ID_SWARM_START_FLAG_CRC);
}
