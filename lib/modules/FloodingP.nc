/*
FloodingP.nc
- Passive neighbor discovery (updates neighbor table on every received packet)
- Duplicate suppression (simple circular buffer cache of recent (src,seq) pairs)
- TTL handling and forwarding to known neighbors via SimpleSend
- Periodic maintenance to age neighbors and cache entries
*/

#include <Timer.h>
#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"

module FloodingP {
  provides interface Flooding;

  uses interface Receive;
  uses interface SimpleSend; // call send(pack, dest)
  uses interface Timer<TMilli> as floodTimer;
  uses interface NeighborDiscover;
}

implementation {

  // Duplicate cache: small circular buffer of recent (src,seq,protocol)
  enum { DUP_CACHE_SIZE = 128 };
  typedef struct {
    uint16_t src;
    uint16_t seq;
    uint8_t protocol;
    uint32_t ts;
  } dup_t;
  dup_t dupCache[DUP_CACHE_SIZE];
  uint8_t dupHead = 0;

  // Simple tick counter (ms approximation)
  uint32_t ticks = 0;
  uint16_t localSeqNum = 0;

  // Helper functions
  bool isDuplicate(uint16_t src, uint16_t seq, uint8_t protocol) {
    int i;
    for (i = 0; i < DUP_CACHE_SIZE; i++) {
      if (dupCache[i].src == src && dupCache[i].seq == seq && 
          dupCache[i].protocol == protocol && dupCache[i].ts > 0) {
        return TRUE;
      }
    }
    return FALSE; 
  }

  void addDup(uint16_t src, uint16_t seq, uint8_t protocol) {
    dupCache[dupHead].src = src;
    dupCache[dupHead].seq = seq;
    dupCache[dupHead].protocol = protocol;
    dupCache[dupHead].ts = ticks;
    dupHead = (dupHead + 1) % DUP_CACHE_SIZE;
  }

  void ageDupCache() {
    int i;
    // Age out entries older than 3 seconds to prevent cache pollution (more aggressive)
    for (i = 0; i < DUP_CACHE_SIZE; i++) {
      if (dupCache[i].ts > 0 && (ticks - dupCache[i].ts) > 3000) {
        dupCache[i].ts = 0; // Mark as invalid
      }
    }
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    pack* p;
    pack sendPack;
    error_t err;
    uint16_t* neighborList;
    uint8_t numNeighbors;
    int i;
    int forwardCount;

    ticks += 1; // increment tick on each receive (approximate)
    if (len < sizeof(pack)) {
      return msg;
    }

    p = (pack*)payload;

    // Let NeighborDiscover handle neighbor discovery for any packet
    call NeighborDiscover.receive(p);

    // Skip neighbor discovery beacons for flooding
    if (p->protocol == 0) {
      // Only show ND beacon debug occasionally to reduce noise
      if (p->seq % 10 == 0) {  // Show every 10th beacon
        dbg(NEIGHBOR_CHANNEL, "ND beacon from %hu received at %hu (seq=%hu) - not flooding\n", 
            p->src, TOS_NODE_ID, p->seq);
      }
      return msg;
    }

    // Debug: Show packet received (as required by spec)
    dbg(FLOODING_CHANNEL, "PACKET: [%hu->%hu] received at Node %hu (TTL=%hu, seq=%hu, proto=%hu)\n", 
        p->src, p->dest, TOS_NODE_ID, p->TTL, p->seq, p->protocol);

    // Duplicate suppression - check BEFORE any processing
    if (isDuplicate(p->src, p->seq, p->protocol)) {
      dbg(FLOODING_CHANNEL, "DUPLICATE: [%hu->%hu] seq=%hu already seen at Node %hu - DROPPED\n", 
          p->src, p->dest, p->seq, TOS_NODE_ID);
      return msg;
    }
    
    // Add to duplicate cache immediately to prevent reprocessing
    addDup(p->src, p->seq, p->protocol);

    // If this packet is for me, deliver (don't forward)
    if (p->dest == TOS_NODE_ID) {
      dbg(FLOODING_CHANNEL, "DELIVERY: [%hu->%hu] REACHED DESTINATION at Node %hu!\n", 
          p->src, p->dest, TOS_NODE_ID);
      
      if (p->protocol == PROTOCOL_PING) {
        dbg(FLOODING_CHANNEL, "PING: Node %hu received ping from %hu, sending reply\n", 
            TOS_NODE_ID, p->src);
        
        // Send ping reply back - DON'T flood, just send to first neighbor
        neighborList = call NeighborDiscover.getNeighbors();
        numNeighbors = call NeighborDiscover.getNumNeighbors();
        
        if (numNeighbors > 0) {
          memcpy(&sendPack, p, sizeof(pack));
          sendPack.dest = p->src;
          sendPack.src = TOS_NODE_ID;
          sendPack.protocol = PROTOCOL_PINGREPLY;
          sendPack.TTL = 2; // Very short TTL for reply
          sendPack.seq = localSeqNum++; // New sequence number for reply
          
          // Send to first neighbor only (not flooding)
          err = call SimpleSend.send(sendPack, neighborList[0]);
          if (err == SUCCESS) {
            dbg(FLOODING_CHANNEL, "REPLY: Node %hu sent ping reply to %hu via neighbor %hu\n", 
                TOS_NODE_ID, p->src, neighborList[0]);
          }
        }
      } else if (p->protocol == PROTOCOL_PINGREPLY) {
        dbg(FLOODING_CHANNEL, "REPLY: Node %hu received ping reply from %hu\n", 
            TOS_NODE_ID, p->src);
      }
      return msg;
    }

    // TTL handling - be very aggressive to limit bouncing
    if (p->TTL <= 1) {
      dbg(FLOODING_CHANNEL, "TTL_EXPIRED: [%hu->%hu] died at Node %hu (TTL=%hu)\n", 
          p->src, p->dest, TOS_NODE_ID, p->TTL);
      return msg;
    }

    // Get neighbors for forwarding
    neighborList = call NeighborDiscover.getNeighbors();
    numNeighbors = call NeighborDiscover.getNumNeighbors();
    
    // Forward to neighbors, but limit propagation
    forwardCount = 0;
    
    for (i = 0; i < numNeighbors && forwardCount < 1; i++) { // Limit to 1 forward only
      uint16_t neighbor = neighborList[i];
      // Don't send back to the node we received from
      if (neighbor != p->src) {
        // Create a copy of the packet
        memcpy(&sendPack, p, sizeof(pack));
        sendPack.TTL = p->TTL - 1;
        
        // Forward the packet
        err = call SimpleSend.send(sendPack, neighbor);
        if (err == SUCCESS) {
          dbg(FLOODING_CHANNEL, "FORWARD: [%hu->%hu] Node %hu forwarded to Node %hu (TTL %hu->%hu)\n", 
              p->src, p->dest, TOS_NODE_ID, neighbor, p->TTL, sendPack.TTL);
          forwardCount++;
        }
      }
    }
    
    if (forwardCount == 0) {
      dbg(FLOODING_CHANNEL, "NO_FORWARD: [%hu->%hu] Node %hu could not forward (no valid neighbors)\n", 
          p->src, p->dest, TOS_NODE_ID);
    }

    return msg;
  }

  // Flooding interface commands
  command void Flooding.start() {
    // start periodic timer for maintenance
    call floodTimer.startPeriodic(1000);
  }

  command void Flooding.stop() {
    call floodTimer.stop();
  }

  event void floodTimer.fired() {
    ticks += 1000; // approximate ms per tick
    ageDupCache(); // Clean up old duplicate cache entries
  }

}
