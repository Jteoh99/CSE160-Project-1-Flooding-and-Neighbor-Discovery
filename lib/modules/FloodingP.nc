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
  uses interface Receive as BeaconReceive;
  uses interface SimpleSend; // call send(pack, dest)
  uses interface Timer<TMilli> as floodTimer;
  uses interface NeighborDiscover;
  uses interface AMPacket;
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
    // Age out entries older than 3 seconds to prevent cache pollution
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
    uint16_t sender; // Node that sent this packet to us

    ticks += 1; // increment tick on each receive (approximate)
    if (len < sizeof(pack)) {
      return msg;
    }

    p = (pack*)payload;
    
    // Get the sender (previous hop) from AM layer
    sender = call AMPacket.source(msg);

    // Only process beacon packets for neighbor discovery (not flooding packets)
    if (p->protocol == 0 && p->dest == 65535) {
      call NeighborDiscover.receive(p);
      return msg; // Skip flooding processing for beacons
    }

    // FLOODING_CHANNEL requirement: show packet received with source location
    dbg(FLOODING_CHANNEL, "RECEIVED: [%hu->%hu] at Node %hu from Node %hu (TTL=%hu, seq=%hu)\n", 
        p->src, p->dest, TOS_NODE_ID, sender, p->TTL, p->seq);

    // Duplicate suppression - check BEFORE any processing
    if (isDuplicate(p->src, p->seq, p->protocol)) {
      // Silent drop - too verbose to log every duplicate
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
          sendPack.TTL = 30; // Higher TTL for reply to reach source
          sendPack.seq = localSeqNum++; // New sequence number for reply
          
          // Use flooding for reply to find correct path back
          err = call Flooding.send(&sendPack, 0);
          if (err == SUCCESS) {
            dbg(FLOODING_CHANNEL, "REPLY: Node %hu sent ping reply to %hu via flooding\n", 
                TOS_NODE_ID, p->src);
          }
        }
      } else if (p->protocol == PROTOCOL_PINGREPLY) {
        dbg(FLOODING_CHANNEL, "REPLY: Node %hu received ping reply from %hu\n", 
            TOS_NODE_ID, p->src);
      }
      return msg;
    }

    // TTL handling
    if (p->TTL <= 1) {
      dbg(FLOODING_CHANNEL, "TTL_EXPIRED: [%hu->%hu] died at Node %hu (TTL=%hu)\n", 
          p->src, p->dest, TOS_NODE_ID, p->TTL);
      return msg;
    }

    // Get neighbors for forwarding
    neighborList = call NeighborDiscover.getNeighbors();
    numNeighbors = call NeighborDiscover.getNumNeighbors();
    
    // TRUE FLOODING: Forward to ALL neighbors except sender
    forwardCount = 0;
    
    for (i = 0; i < numNeighbors; i++) {
      uint16_t neighbor = neighborList[i];
      
      // Don't send back to the node we received this packet from (sender)
      if (neighbor != sender) {
        // Create a copy of the packet
        memcpy(&sendPack, p, sizeof(pack));
        sendPack.TTL = p->TTL - 1;
        
        // Forward the packet
        err = call SimpleSend.send(sendPack, neighbor);
        if (err == SUCCESS) {
          // FLOODING_CHANNEL requirement: show packet sent with source location
          dbg(FLOODING_CHANNEL, "SENT: [%hu->%hu] from Node %hu to Node %hu (TTL %hu->%hu)\n", 
              p->src, p->dest, TOS_NODE_ID, neighbor, p->TTL, sendPack.TTL);
          forwardCount++;
        }
      }
    }
    
    // Show when no forwarding is possible
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

  command error_t Flooding.send(pack *packet, uint16_t dest) {
    uint16_t* neighborList;
    uint8_t numNeighbors;
    int i;
    error_t err = FAIL;
    int sentCount = 0;
    
    dbg(FLOODING_CHANNEL, "FLOOD_SEND: Node %hu initiating flood for packet %hu->%hu (protocol=%hu)\n", 
        TOS_NODE_ID, packet->src, packet->dest, packet->protocol);
    
    // Add to duplicate cache to prevent looping back to source
    addDup(packet->src, packet->seq, packet->protocol);
    
    // Get all neighbors and flood to all of them
    neighborList = call NeighborDiscover.getNeighbors();
    numNeighbors = call NeighborDiscover.getNumNeighbors();
    
    for (i = 0; i < numNeighbors; i++) {
      error_t result = call SimpleSend.send(*packet, neighborList[i]);
      if (result == SUCCESS) {
        sentCount++;
        err = SUCCESS; // At least one send succeeded
      }
    }
    
    if (sentCount == 0) {
      dbg(FLOODING_CHANNEL, "FLOOD_FAIL: Node %hu could not send to any neighbors\n", TOS_NODE_ID);
    }
    
    return err;
  }

  event void floodTimer.fired() {
    ticks += 1000; // approximate ms per tick
    ageDupCache(); // Clean up old duplicate cache entries
  }

  // Handle beacon packets on AM_PACK channel
  event message_t* BeaconReceive.receive(message_t* msg, void* payload, uint8_t len) {
    pack* p;

    if (len < sizeof(pack)) {
      return msg;
    }

    p = (pack*)payload;
    
    // Only process beacon packets (protocol 0, broadcast dest)
    if (p->protocol == 0 && p->dest == 65535) {
      call NeighborDiscover.receive(p);
    }
    
    return msg;
  }

}
