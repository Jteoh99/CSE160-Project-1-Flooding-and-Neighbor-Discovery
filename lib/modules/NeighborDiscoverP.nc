#include <Timer.h>
#include "../../includes/channels.h"
#include "../../includes/packet.h"

generic module NeighborDiscoverP() {
    provides interface NeighborDiscover;
    uses interface Timer<TMilli> as neighborTimer;
    uses interface Timer<TMilli> as printTimer;
    uses interface Random;
    uses interface SimpleSend;
}

implementation {
    enum { MAX_NEIGHBORS = 32 };
    typedef struct {
        uint16_t id;
        uint32_t lastSeen;
        bool valid;
    } neighbor_t;
    neighbor_t neighbors[MAX_NEIGHBORS];
    uint32_t ticks = 0;
    
    // Cached neighbor list for flooding
    uint16_t cachedNeighbors[MAX_NEIGHBORS];
    uint8_t numCachedNeighbors = 0;

    // Function prototypes
    void updateNeighborCache();

    // Update cached neighbor list for fast access
    void updateNeighborCache() {
        int i;
        numCachedNeighbors = 0;
        for (i = 0; i < MAX_NEIGHBORS; i++) {
            if (neighbors[i].valid) {
                cachedNeighbors[numCachedNeighbors] = neighbors[i].id;
                numCachedNeighbors++;
            }
        }
    }

    // Add or update neighbor in table
    void addOrUpdateNeighbor(uint16_t id) {
        int i;
        uint32_t oldest = 0xFFFFFFFF;
        int oldestIdx = 0;
        for (i = 0; i < MAX_NEIGHBORS; i++) {
            if (neighbors[i].valid && neighbors[i].id == id) {
                neighbors[i].lastSeen = ticks;
                updateNeighborCache();
                return;
            }
        }
        for (i = 0; i < MAX_NEIGHBORS; i++) {
            if (!neighbors[i].valid) {
                neighbors[i].valid = TRUE;
                neighbors[i].id = id;
                neighbors[i].lastSeen = ticks;
                updateNeighborCache();
                return;
            }
        }
        for (i = 0; i < MAX_NEIGHBORS; i++) {
            if (neighbors[i].lastSeen < oldest) {
                oldest = neighbors[i].lastSeen;
                oldestIdx = i;
            }
        }
        neighbors[oldestIdx].id = id;
        neighbors[oldestIdx].lastSeen = ticks;
        neighbors[oldestIdx].valid = TRUE;
        updateNeighborCache();
    }

    // Age out old neighbors
    void ageNeighbors() {
        uint32_t ageLimit = 10000; // 10 seconds - longer than beacon interval (2-3s)
        int i;
        bool changed = FALSE;
        for (i = 0; i < MAX_NEIGHBORS; i++) {
            if (neighbors[i].valid && (ticks - neighbors[i].lastSeen) > ageLimit) {
                neighbors[i].valid = FALSE;
                changed = TRUE;
            }
        }
        if (changed) {
            updateNeighborCache();
        }
    }

    command void NeighborDiscover.findNeighbors() {
        uint16_t delay = (call Random.rand16() % 300) + 100;
        int i;
        
        // Clear all existing neighbors on startup
        for (i = 0; i < MAX_NEIGHBORS; i++) {
            neighbors[i].valid = FALSE;
        }
        updateNeighborCache();
        
        call neighborTimer.startOneShot(delay);
        // Start periodic neighbor printing after 10 seconds to allow discovery
        call printTimer.startOneShot(10000);
    }

    task void search() {
        // Send beacon packet to all nodes (broadcast)
        pack beacon;
        error_t result;
        beacon.src = TOS_NODE_ID;
        beacon.dest = 0xFFFF; // broadcast
        beacon.seq = ticks;
        beacon.TTL = 1;
        beacon.protocol = 0; // protocol for neighbor discovery
        memcpy(beacon.payload, "ND", 3);
        result = call SimpleSend.send(beacon, beacon.dest);
        call neighborTimer.startPeriodic((call Random.rand16() % 500) + 1000); // More frequent: 1-1.5 seconds
    }

    event void neighborTimer.fired() {
        ticks += 1250; // Update tick increment to match new timer (average of 1-1.5s)
        ageNeighbors();
        post search();
    }

    // Check if two nodes should be neighbors - accept all reachable nodes
    bool isValidNeighbor(uint16_t myNode, uint16_t neighborNode) {
        // Accept any neighbor that can send beacons to us
        // The simulation topology file handles radio connectivity constraints
        return TRUE;
    }

    // Call this from Receive.receive when a beacon is received
    void receiveBeacon(uint16_t src) {
        // Accept any valid beacon (topology handled by simulation)
        if (isValidNeighbor(TOS_NODE_ID, src)) {
            addOrUpdateNeighbor(src);
        }
    }

    command void NeighborDiscover.receive(pack* msg) {
        // Handle neighbor discovery packets
        if (msg->protocol == 0 && msg->src != TOS_NODE_ID) {
            // This is a neighbor discovery beacon
            receiveBeacon(msg->src);
        }
        // Note: Removed passive neighbor discovery for flooding packets
        // to prevent adding distant nodes as neighbors through multi-hop paths
    }

    command void NeighborDiscover.printNeighbors() {
        int i;
        int neighborCount = 0;
        uint16_t neighborList[MAX_NEIGHBORS];
        char outputStr[256];  // Buffer for building the output string
        char tempStr[32];     // Temporary buffer for individual neighbor IDs
        
        // Collect all valid neighbors
        for (i = 0; i < MAX_NEIGHBORS; i++) {
            if (neighbors[i].valid) {
                neighborList[neighborCount] = neighbors[i].id;
                neighborCount++;
            }
        }
        
        // Build the complete output string
        if (neighborCount > 0) {
            sprintf(outputStr, "NEIGHBORS: Node %hu has %d neighbors: [", TOS_NODE_ID, neighborCount);
            for (i = 0; i < neighborCount; i++) {
                if (i > 0) {
                    strcat(outputStr, ", ");
                }
                sprintf(tempStr, "%hu", neighborList[i]);
                strcat(outputStr, tempStr);
            }
            strcat(outputStr, "]");
        } else {
            sprintf(outputStr, "NEIGHBORS: Node %hu has 0 neighbors: []", TOS_NODE_ID);
        }
        
        // Output the complete string in a single dbg() call
        dbg(NEIGHBOR_CHANNEL, "%s\n", outputStr);
    }

    event void printTimer.fired() {
        // Print neighbors with clear separation only once after discovery period
        call NeighborDiscover.printNeighbors();
        // Don't restart the timer print only once
    }

    command uint16_t* NeighborDiscover.getNeighbors() {
        return cachedNeighbors;
    }

    command uint8_t NeighborDiscover.getNumNeighbors() {
        return numCachedNeighbors;
    }
}