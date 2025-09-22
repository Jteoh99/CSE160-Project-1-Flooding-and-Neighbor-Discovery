/*
 * FloodingP.nc
 *
 * Full implementation of a basic flooding module for Project 1.
 * Features:
 *  - Passive neighbor discovery (updates neighbor table on every received packet)
 *  - Duplicate suppression (simple circular buffer cache of recent (src,seq) pairs)
 *  - TTL handling and forwarding to known neighbors via SimpleSend
 *  - Periodic maintenance to age neighbors and cache entries
 *
 * Notes:
 *  - This implementation prefers simplicity and clarity over efficiency.
 *  - For production use, replace static arrays with the provided Hashmap/List
 *    implementations in dataStructures/ for better scalability.
 */

#include <Timer.h>
#include "../../includes/channels.h"
#include "../../includes/packet.h"

module FloodingP() {
  provides interface Flooding;

  uses interface Receive;
  uses interface SimpleSend; // call send(pack, dest)
  uses interface Timer<TMilli> as floodTimer;
}

implementation {

  // Simple neighbor table entry
  enum { MAX_NEIGHBORS = 32 };
  typedef struct {
    uint16_t id;
    uint32_t lastSeen; // simulation time in ms (we'll use a tick counter)
    bool valid;
  } neighbor_t;

  neighbor_t neighbors[MAX_NEIGHBORS];

  // Duplicate cache: small circular buffer of recent (src,seq)
  enum { DUP_CACHE_SIZE = 64 };
  typedef struct {
    uint16_t src;
    uint16_t seq;
    uint32_t ts;
  } dup_t;
  dup_t dupCache[DUP_CACHE_SIZE];
  uint8_t dupHead = 0;

  // Simple tick counter (ms approximation)
  uint32_t ticks = 0;

  // Helper functions
  void addOrUpdateNeighbor(uint16_t id) {
    int i;
    for (i = 0; i < MAX_NEIGHBORS; i++) {
      if (neighbors[i].valid && neighbors[i].id == id) {
        neighbors[i].lastSeen = ticks;
        return;
      }
    }
    // find empty slot
    for (i = 0; i < MAX_NEIGHBORS; i++) {
      if (!neighbors[i].valid) {
        neighbors[i].valid = TRUE;
        neighbors[i].id = id;
        neighbors[i].lastSeen = ticks;
        dbg(NEIGHBOR_CHANNEL, "Added neighbor %hu at node %hu\n", id, TOS_NODE_ID);
        return;
      }
    }
    // no space: overwrite oldest
    uint32_t oldest = 0xFFFFFFFF;
    int oldestIdx = 0;
    for (i = 0; i < MAX_NEIGHBORS; i++) {
      if (neighbors[i].lastSeen < oldest) {
        oldest = neighbors[i].lastSeen;
        oldestIdx = i;
      }
    }
    neighbors[oldestIdx].id = id;
    neighbors[oldestIdx].lastSeen = ticks;
    neighbors[oldestIdx].valid = TRUE;
    dbg(NEIGHBOR_CHANNEL, "Replaced neighbor at slot %d with %hu at node %hu\n", oldestIdx, id, TOS_NODE_ID);
  }

  bool isDuplicate(uint16_t src, uint16_t seq) {
    int i;
    for (i = 0; i < DUP_CACHE_SIZE; i++) {
      if (dupCache[i].src == src && dupCache[i].seq == seq) return TRUE;
    }
    return FALSE;
  }

  void addDup(uint16_t src, uint16_t seq) {
    dupCache[dupHead].src = src;
    dupCache[dupHead].seq = seq;
    dupCache[dupHead].ts = ticks;
    dupHead = (dupHead + 1) % DUP_CACHE_SIZE;
  }

  void ageTables() {
    // Age neighbors: remove entries older than 30 seconds (30000 ms)
    uint32_t ageLimit = 30000;
    int i;
    for (i = 0; i < MAX_NEIGHBORS; i++) {
      if (neighbors[i].valid && (ticks - neighbors[i].lastSeen) > ageLimit) {
        dbg(NEIGHBOR_CHANNEL, "Neighbor %hu aged out at node %hu\n", neighbors[i].id, TOS_NODE_ID);
        neighbors[i].valid = FALSE;
      }
    }
    // Optionally age duplicates: no-op here (circular buffer overwrites old entries)
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    ticks += 1; // increment tick on each receive (approximate)
    dbg(FLOODING_CHANNEL, "Packet Received at node %hu (len=%hhu)\n", TOS_NODE_ID, len);
    if (len < sizeof(pack)) {
      dbg(FLOODING_CHANNEL, "Unknown packet size: %d\n", len);
      return msg;
    }

    pack* p = (pack*)payload;

    // Passive neighbor discovery
    if (p->src != TOS_NODE_ID) {
      addOrUpdateNeighbor(p->src);
    }

    // If this packet is for me, deliver
    if (p->dest == TOS_NODE_ID) {
      dbg(FLOODING_CHANNEL, "Delivering packet at %hu from %hu\n", TOS_NODE_ID, p->src);
      return msg;
    }

    // Duplicate suppression
    if (isDuplicate(p->src, p->seq)) {
      dbg(FLOODING_CHANNEL, "Duplicate packet dropped at %hu (src=%hu,seq=%hu)\n", TOS_NODE_ID, p->src, p->seq);
      return msg;
    }
    addDup(p->src, p->seq);

    // TTL handling
    if (p->TTL == 0) {
      dbg(FLOODING_CHANNEL, "TTL expired at %hu for packet from %hu\n", TOS_NODE_ID, p->src);
      return msg;
    }

    // Prepare forwarding: decrement TTL and forward to all neighbors
    p->TTL = p->TTL - 1;

    int i;
    for (i = 0; i < MAX_NEIGHBORS; i++) {
      if (neighbors[i].valid) {
        uint16_t dest = neighbors[i].id;
        if (dest == p->src) continue; // don't send back to origin directly
        // send a copy: create a local pack copy to send
        pack sendPack;
        memcpy(&sendPack, p, sizeof(pack));
        // set sendPack.src to this node
        sendPack.src = TOS_NODE_ID;
        // send via SimpleSend
        error_t err = call SimpleSend.send(sendPack, dest);
        if (err == SUCCESS) {
          dbg(FLOODING_CHANNEL, "Forwarded packet from %hu to %hu at node %hu\n", p->src, dest, TOS_NODE_ID);
        } else {
          dbg(FLOODING_CHANNEL, "Failed to forward packet to %hu at node %hu (err=%d)\n", dest, TOS_NODE_ID, err);
        }
      }
    }

    return msg;
  }

  // Flooding interface commands
  command void Flooding.start() {
    // start periodic timer to age tables every second
    call floodTimer.startPeriodic(1000);
    dbg(FLOODING_CHANNEL, "Flooding started on node %hu\n", TOS_NODE_ID);
  }

  command void Flooding.stop() {
    call floodTimer.stop();
    dbg(FLOODING_CHANNEL, "Flooding stopped on node %hu\n", TOS_NODE_ID);
  }

  command void Flooding.printNeighbors() {
    int i;
    for (i = 0; i < MAX_NEIGHBORS; i++) {
      if (neighbors[i].valid) {
        dbg(NEIGHBOR_CHANNEL, "Neighbor: %hu lastSeen: %lu at node %hu\n", neighbors[i].id, neighbors[i].lastSeen, TOS_NODE_ID);
      }
    }
  }

  event void floodTimer.fired() {
    ticks += 1000; // approximate ms per tick
    ageTables();
  }

}
