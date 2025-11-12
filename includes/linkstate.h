//Author: UCM ANDES Lab
//$Author: abeltran2 $
//$LastChangedBy: abeltran2 $

#ifndef LINKSTATE_H
#define LINKSTATE_H

#include "packet.h"

// Maximum number of neighbors that can be advertised in one link-state packet
enum{
    MAX_NEIGHBORS_PER_LS_PACKET = 10,  // Fits in 20-byte payload
    MAX_ROUTES = 32,                   // Maximum routing table entries
    LS_INVALID_ROUTE = 0xFFFF          // Invalid route indicator
};

// Link-State Advertisement structure (fits in packet payload)
typedef nx_struct LinkStatePacket {
    nx_uint16_t sourceNode;                                    // Node advertising its links
    nx_uint8_t numNeighbors;                                   // Number of neighbors in this packet
    nx_uint16_t neighbors[MAX_NEIGHBORS_PER_LS_PACKET];       // List of neighbor node IDs
    nx_uint16_t sequenceNum;                                   // LSA sequence number
} LinkStatePacket;

// Routing table entry
typedef struct RouteEntry {
    uint16_t destination;     // Destination node
    uint16_t nextHop;        // Next hop neighbor
    uint16_t cost;           // Path cost (hop count)
    bool valid;              // Entry validity
} RouteEntry;

// Link-State Database entry (for storing received LSAs)
typedef struct LSAEntry {
    uint16_t sourceNode;                           // Node that originated this LSA
    uint16_t sequenceNum;                          // LSA sequence number
    uint8_t numNeighbors;                          // Number of neighbors
    uint16_t neighbors[MAX_NEIGHBORS_PER_LS_PACKET]; // Neighbor list
    uint32_t timestamp;                            // When LSA was received
    bool valid;                                    // Entry validity
} LSAEntry;

#endif /* LINKSTATE_H */