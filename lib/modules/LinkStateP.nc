#include <Timer.h>
#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/linkstate.h"

module LinkStateP {
    provides interface LinkState;
    
    uses interface Timer<TMilli> as LSATimer;
    uses interface Timer<TMilli> as CalculationTimer;
    uses interface Random;
    uses interface SimpleSend;
    uses interface NeighborDiscover;
}

implementation {
    
    // STATE VARIABLES
    
    // Link-State Database: stores LSAs from all nodes
    LSAEntry linkStateDB[MAX_ROUTES];
    
    // Routing Table: computed from link-state database
    RouteEntry routingTable[MAX_ROUTES];
    
    // Local protocol state
    uint16_t mySequenceNum;
    uint32_t ticks = 0;
    bool started = FALSE;
    
    // Neighbor change tracking
    bool neighborsChanged = TRUE;
    
    // LSA generation tracking
    uint8_t lsaGeneration = 0;
    uint8_t maxGenerations = 25;  // More LSAs for circle topology
    
    // Failed neighbor tracking to prevent accepting LSAs from recently failed neighbors
    uint16_t recentlyFailedNodes[MAX_NEIGHBORS_PER_LS_PACKET];
    uint32_t failureTimestamps[MAX_NEIGHBORS_PER_LS_PACKET];
    uint8_t numFailedNodes = 0;
    
    // FUNCTION PROTOTYPES
    
    void initializeLSDB();
    void initializeRoutingTable();
    void generateLSA();
    void processLSA(LinkStatePacket* lsa, uint16_t sourceNode);
    task void calculateRoutingTable();
    void dijkstraShortestPath();
    bool isNewerLSA(uint16_t sourceNode, uint16_t sequenceNum);
    void updateLSDBEntry(LinkStatePacket* lsa, uint16_t sourceNode);
    void ageLSAs();
    bool validateLSA(LinkStatePacket* lsa);
    void cleanupStaleLSAs();
    void printRouteEntry(RouteEntry* entry);
    int countValidLSAs();
    void addFailedNode(uint16_t nodeId);
    bool isRecentlyFailedNode(uint16_t nodeId);
    void cleanupFailedNodes();
    
    // INITIALIZATION FUNCTIONS
    
    void initializeLSDB() {
        int i;
        for (i = 0; i < MAX_ROUTES; i++) {
            linkStateDB[i].valid = FALSE;
            linkStateDB[i].sourceNode = 0;
            linkStateDB[i].sequenceNum = 0;
            linkStateDB[i].numNeighbors = 0;
            linkStateDB[i].timestamp = 0;
        }
    }
    
    void initializeRoutingTable() {
        int i;
        for (i = 0; i < MAX_ROUTES; i++) {
            routingTable[i].valid = FALSE;
            routingTable[i].destination = 0;
            routingTable[i].nextHop = 0;
            routingTable[i].cost = 0;
        }
        
        // Always add self-route
        routingTable[0].valid = TRUE;
        routingTable[0].destination = TOS_NODE_ID;
        routingTable[0].nextHop = TOS_NODE_ID;
        routingTable[0].cost = 0;
    }
    
    int countValidLSAs() {
        int count = 0;
        int i;
        for (i = 0; i < MAX_ROUTES; i++) {
            if (linkStateDB[i].valid) {
                count++;
            }
        }
        return count;
    }
    
    // LSA GENERATION AND PROCESSING
    
    void generateLSA() {
        pack lsaPacket;
        LinkStatePacket lsa;
        int i;
        uint16_t* currentNeighbors;
        uint8_t numCurrentNeighbors;
        error_t result;
        
        // Get current neighbor information
        currentNeighbors = call NeighborDiscover.getNeighbors();
        numCurrentNeighbors = call NeighborDiscover.getNumNeighbors();
        
        if (currentNeighbors == NULL) {
            call LSATimer.startOneShot(2000);
            return;
        }
        
        // Create LSA
        lsa.sourceNode = TOS_NODE_ID;
        lsa.sequenceNum = mySequenceNum++;
        lsa.numNeighbors = (numCurrentNeighbors > MAX_NEIGHBORS_PER_LS_PACKET) ? 
                          MAX_NEIGHBORS_PER_LS_PACKET : numCurrentNeighbors;
        
        for (i = 0; i < lsa.numNeighbors; i++) {
            lsa.neighbors[i] = currentNeighbors[i];
        }
        
        // Update our own LSA in database first
        updateLSDBEntry(&lsa, TOS_NODE_ID);
        
        // Create and send LSA packet
        lsaPacket.src = TOS_NODE_ID;
        lsaPacket.dest = 0xFFFF;  // Broadcast
        lsaPacket.seq = lsa.sequenceNum;
        lsaPacket.TTL = 50;  // Increased TTL for large topologies
        lsaPacket.protocol = PROTOCOL_LINKSTATE;
        
        memcpy(lsaPacket.payload, &lsa, sizeof(LinkStatePacket));
        
        result = call SimpleSend.send(lsaPacket, 0xFFFF);
        if (result == SUCCESS) {
            // Schedule routing table calculation with shorter delay for faster convergence
            call CalculationTimer.startOneShot(1000);
        }
        
        neighborsChanged = FALSE;
    }
    
    bool validateLSA(LinkStatePacket* lsa) {
        int i;
        
        // Always accept our own LSAs
        if (lsa->sourceNode == TOS_NODE_ID) {
            return TRUE;
        }
        
        // Reject LSAs from recently failed neighbors
        if (isRecentlyFailedNode(lsa->sourceNode)) {
            return FALSE;
        }
        
        // Basic validation: check for reasonable values
        if (lsa->numNeighbors > MAX_NEIGHBORS_PER_LS_PACKET) {
            return FALSE;
        }
        
        // Check for duplicate neighbors in the LSA
        for (i = 0; i < lsa->numNeighbors; i++) {
            int j;
            for (j = i + 1; j < lsa->numNeighbors; j++) {
                if (lsa->neighbors[i] == lsa->neighbors[j]) {
                    return FALSE;
                }
            }
        }
        
        // Accept all other LSAs and let flooding protocol handle distribution
        return TRUE;
    }
    
    void processLSA(LinkStatePacket* lsa, uint16_t sourceNode) {
        if (lsa->sourceNode != sourceNode) {
            return;  // Source mismatch
        }
        
        // Validate LSA before processing
        if (!validateLSA(lsa)) {
            return;
        }
        
        // Check if this is a newer LSA
        if (isNewerLSA(lsa->sourceNode, lsa->sequenceNum)) {
            updateLSDBEntry(lsa, sourceNode);
            
            // Single routing calculation to avoid timer conflicts
            call CalculationTimer.startOneShot(500);
        }
    }
    
    bool isNewerLSA(uint16_t sourceNode, uint16_t sequenceNum) {
        int i;
        for (i = 0; i < MAX_ROUTES; i++) {
            if (linkStateDB[i].valid && linkStateDB[i].sourceNode == sourceNode) {
                // Handle sequence number wraparound
                int16_t seqDiff = (int16_t)(sequenceNum - linkStateDB[i].sequenceNum);
                return (seqDiff > 0);
            }
        }
        return TRUE;  // First LSA from this node
    }
    
    void updateLSDBEntry(LinkStatePacket* lsa, uint16_t sourceNode) {
        int i, j;
        int freeSlot = -1;
        
        // Don't update LSAs from recently failed nodes and let them age out
        if (isRecentlyFailedNode(lsa->sourceNode)) {
            return;
        }
        
        // Find existing entry or free slot
        for (i = 0; i < MAX_ROUTES; i++) {
            if (linkStateDB[i].valid && linkStateDB[i].sourceNode == lsa->sourceNode) {
                // Update existing entry
                linkStateDB[i].sequenceNum = lsa->sequenceNum;
                linkStateDB[i].numNeighbors = lsa->numNeighbors;
                linkStateDB[i].timestamp = ticks;
                
                for (j = 0; j < lsa->numNeighbors; j++) {
                    linkStateDB[i].neighbors[j] = lsa->neighbors[j];
                }
                return;
            } else if (!linkStateDB[i].valid && freeSlot == -1) {
                freeSlot = i;
            }
        }
        
        // Don't create new entries for recently failed nodes
        if (isRecentlyFailedNode(lsa->sourceNode)) {
            return;
        }
        
        // Create new entry
        if (freeSlot != -1) {
            linkStateDB[freeSlot].valid = TRUE;
            linkStateDB[freeSlot].sourceNode = lsa->sourceNode;
            linkStateDB[freeSlot].sequenceNum = lsa->sequenceNum;
            linkStateDB[freeSlot].numNeighbors = lsa->numNeighbors;
            linkStateDB[freeSlot].timestamp = ticks;
            
            for (j = 0; j < lsa->numNeighbors; j++) {
                linkStateDB[freeSlot].neighbors[j] = lsa->neighbors[j];
            }
        }
    }
    
    // LSA AGING AND CLEANUP
    
    void ageLSAs() {
        int i, j;
        uint16_t* myNeighbors;
        uint8_t numMyNeighbors;
        bool changed = FALSE;
        bool shouldRemove;
        
        myNeighbors = call NeighborDiscover.getNeighbors();
        numMyNeighbors = call NeighborDiscover.getNumNeighbors();
        
        for (i = 0; i < MAX_ROUTES; i++) {
            if (linkStateDB[i].valid && linkStateDB[i].sourceNode != TOS_NODE_ID) {
                uint32_t age = ticks - linkStateDB[i].timestamp;
                bool isDirectNeighbor = FALSE;
                
                // Check if this node is still our direct neighbor
                for (j = 0; j < numMyNeighbors; j++) {
                    if (myNeighbors[j] == linkStateDB[i].sourceNode) {
                        isDirectNeighbor = TRUE;
                        break;
                    }
                }
                
                // Age out old LSAs - be more responsive to failures
                shouldRemove = FALSE;
                // Use different timeouts based on whether it's a direct neighbor
                if (isDirectNeighbor && age > 15000) {  // 15 seconds for direct neighbors (faster failure detection)
                    shouldRemove = TRUE;
                } else if (!isDirectNeighbor && age > 90000) {  // 90 seconds for non-neighbors (more conservative for fragmented networks)
                    shouldRemove = TRUE;
                } else if (age > 120000) {  // 120 seconds maximum age (more conservative to preserve topology during failures)
                    shouldRemove = TRUE;
                }
                
                if (shouldRemove) {
                    linkStateDB[i].valid = FALSE;
                    changed = TRUE;
                }
            }
        }
        
        if (changed) {
            post calculateRoutingTable();
        }
    }
    
    void cleanupStaleLSAs() {
        int i, j, k;
        uint16_t* myNeighbors;
        uint8_t numMyNeighbors;
        bool changed = FALSE;
        
        myNeighbors = call NeighborDiscover.getNeighbors();
        numMyNeighbors = call NeighborDiscover.getNumNeighbors();
        
        // Remove LSAs from nodes that were direct neighbors but no longer are
        for (i = 0; i < MAX_ROUTES; i++) {
            if (linkStateDB[i].valid && linkStateDB[i].sourceNode != TOS_NODE_ID) {
                bool wasDirectNeighbor = FALSE;
                bool isCurrentNeighbor = FALSE;
                
                // Check if this was a direct neighbor (had recent LSA)
                uint32_t age = ticks - linkStateDB[i].timestamp;
                if (age < 30000) {  // Recent LSA (within 3 LSA periods)
                    wasDirectNeighbor = TRUE;
                }
                
                // Check if it's still our direct neighbor
                for (j = 0; j < numMyNeighbors; j++) {
                    if (myNeighbors[j] == linkStateDB[i].sourceNode) {
                        isCurrentNeighbor = TRUE;
                        break;
                    }
                }
                
                // If it was a direct neighbor but no longer is, remove immediately
                if (wasDirectNeighbor && !isCurrentNeighbor) {
                    linkStateDB[i].valid = FALSE;
                    changed = TRUE;
                }
            }
        }
        
        if (changed) {
            post calculateRoutingTable();
        }
    }
    
    // ROUTING TABLE CALCULATION (DIJKSTRA)
    
    task void calculateRoutingTable() {
        initializeRoutingTable();
        dijkstraShortestPath();
    }
    
    void dijkstraShortestPath() {
        uint16_t distance[MAX_ROUTES];
        uint16_t previous[MAX_ROUTES];
        bool visited[MAX_ROUTES];
        uint16_t nodeMap[MAX_ROUTES];
        int numNodes = 0;
        int i, j, u, v, n;
        int neighborIdx, pathNode;
        uint16_t minDistance, currentNode, neighbor;
        uint16_t dest, nextHop, alt;
        int routeIndex = 1;  // Start after self-route
        
        // Build node map from LSA database
        nodeMap[numNodes++] = TOS_NODE_ID;  // Add ourselves first
        
        for (i = 0; i < MAX_ROUTES; i++) {
            if (linkStateDB[i].valid) {
                bool found = FALSE;
                // Add source node
                for (j = 0; j < numNodes; j++) {
                    if (nodeMap[j] == linkStateDB[i].sourceNode) {
                        found = TRUE;
                        break;
                    }
                }
                if (!found && numNodes < MAX_ROUTES) {
                    nodeMap[numNodes++] = linkStateDB[i].sourceNode;
                }
                
                // Add neighbor nodes
                for (j = 0; j < linkStateDB[i].numNeighbors && numNodes < MAX_ROUTES; j++) {
                    neighbor = linkStateDB[i].neighbors[j];
                    found = FALSE;
                    for (u = 0; u < numNodes; u++) {
                        if (nodeMap[u] == neighbor) {
                            found = TRUE;
                            break;
                        }
                    }
                    if (!found) {
                        nodeMap[numNodes++] = neighbor;
                    }
                }
            }
        }
        
        // Debug: Print node map for Node 18 only during development
        // if (TOS_NODE_ID == 18) {
        //     dbg(GENERAL_CHANNEL, "DIJKSTRA: Node %hu has %d nodes in topology\n", TOS_NODE_ID, numNodes);
        //     for (i = 0; i < numNodes; i++) {
        //         dbg(GENERAL_CHANNEL, "DIJKSTRA: nodeMap[%d] = %d\n", i, nodeMap[i]);
        //     }
        // }
        
        // Initialize Dijkstra arrays
        for (i = 0; i < numNodes; i++) {
            distance[i] = 0xFFFF;
            previous[i] = 0xFFFF;
            visited[i] = FALSE;
        }
        distance[0] = 0;  // Distance to ourselves
        
        // Main Dijkstra loop
        for (i = 0; i < numNodes; i++) {
            // Find minimum distance unvisited node
            minDistance = 0xFFFF;
            u = -1;
            for (j = 0; j < numNodes; j++) {
                if (!visited[j] && distance[j] < minDistance) {
                    minDistance = distance[j];
                    u = j;
                }
            }
            
            if (u == -1 || minDistance == 0xFFFF) break;
            
            visited[u] = TRUE;
            currentNode = nodeMap[u];
            
            // Find LSA for current node and update distances to neighbors
            for (j = 0; j < MAX_ROUTES; j++) {
                if (linkStateDB[j].valid && linkStateDB[j].sourceNode == currentNode) {
                    for (v = 0; v < linkStateDB[j].numNeighbors; v++) {
                        neighbor = linkStateDB[j].neighbors[v];
                        neighborIdx = -1;
                        
                        // Find neighbor in node map
                        for (n = 0; n < numNodes; n++) {
                            if (nodeMap[n] == neighbor) {
                                neighborIdx = n;
                                break;
                            }
                        }
                        
                        if (neighborIdx != -1 && !visited[neighborIdx]) {
                            alt = distance[u] + 1;  // Unit cost links
                            if (alt < distance[neighborIdx]) {
                                distance[neighborIdx] = alt;
                                previous[neighborIdx] = u;
                            }
                        }
                    }
                    break;
                }
            }
            
            // WORKAROUND: Also check for reverse edges
            // If other nodes list currentNode as a neighbor, treat it as bidirectional
            for (j = 0; j < MAX_ROUTES; j++) {
                if (linkStateDB[j].valid && linkStateDB[j].sourceNode != currentNode) {
                    for (v = 0; v < linkStateDB[j].numNeighbors; v++) {
                        if (linkStateDB[j].neighbors[v] == currentNode) {
                            // Found reverse edge: linkStateDB[j].sourceNode -> currentNode
                            neighbor = linkStateDB[j].sourceNode;
                            neighborIdx = -1;
                            
                            // Find neighbor in node map
                            for (n = 0; n < numNodes; n++) {
                                if (nodeMap[n] == neighbor) {
                                    neighborIdx = n;
                                    break;
                                }
                            }
                            
                            if (neighborIdx != -1 && !visited[neighborIdx]) {
                                alt = distance[u] + 1;  // Unit cost links
                                if (alt < distance[neighborIdx]) {
                                    distance[neighborIdx] = alt;
                                    previous[neighborIdx] = u;
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Removed verbose diagnostic output for cleaner logs

        // Build routing table from Dijkstra results  
        for (i = 1; i < numNodes && routeIndex < MAX_ROUTES; i++) {
            if (distance[i] != 0xFFFF) {  // Reachable node
                dest = nodeMap[i];
                
                // Trace back to find next hop
                pathNode = i;
                while (pathNode != 0xFFFF && previous[pathNode] != 0 && previous[pathNode] != 0xFFFF) {
                    pathNode = previous[pathNode];
                }
                
                if (pathNode != 0xFFFF && pathNode != i && previous[pathNode] == 0) {
                    nextHop = nodeMap[pathNode];
                } else if (previous[i] == 0) {
                    nextHop = dest;  // Direct neighbor
                } else {
                    // Skip invalid paths
                    continue;
                }
                
                // Add to routing table
                routingTable[routeIndex].valid = TRUE;
                routingTable[routeIndex].destination = dest;
                routingTable[routeIndex].nextHop = nextHop;
                routingTable[routeIndex].cost = distance[i];
                routeIndex++;
            }
        }
    }
    
    // INTERFACE IMPLEMENTATIONS
    
    command void LinkState.start() {
        if (!started) {
            mySequenceNum = call Random.rand16() % 10000 + 20000;
            lsaGeneration = 0;
            numFailedNodes = 0;  // Initialize failed node tracking
            
            initializeLSDB();
            initializeRoutingTable();
            
            // Single timer approach to avoid conflicts
            call LSATimer.startPeriodic(20000);  // Every 20 seconds
            
            started = TRUE;
        }
    }
    
    command void LinkState.stop() {
        call LSATimer.stop();
        call CalculationTimer.stop();
        started = FALSE;
    }
    
    command void LinkState.receive(void* msg) {
        pack* packet = (pack*)msg;
        LinkStatePacket* lsa;
        
        if (packet->protocol == PROTOCOL_LINKSTATE) {
            lsa = (LinkStatePacket*)(packet->payload);
            processLSA(lsa, packet->src);
        }
    }
    
    command void LinkState.updateLinkState() {
        neighborsChanged = TRUE;
        generateLSA();
        cleanupStaleLSAs();
    }
    
    command uint16_t LinkState.getNextHop(uint16_t destination) {
        int i;
        for (i = 0; i < MAX_ROUTES; i++) {
            if (routingTable[i].valid && routingTable[i].destination == destination) {
                return routingTable[i].nextHop;
            }
        }
        return LS_INVALID_ROUTE;
    }
    
    command bool LinkState.hasRoute(uint16_t destination) {
        return (call LinkState.getNextHop(destination) != LS_INVALID_ROUTE);
    }
    
    command error_t LinkState.route(void* packet, uint16_t nextHop) {
        pack* pkt = (pack*)packet;
        
        if (nextHop == LS_INVALID_ROUTE) {
            return FAIL;
        }
        
        return call SimpleSend.send(*pkt, nextHop);
    }
    
    command void LinkState.printLinkState() {
        // Diagnostic output for debugging LSA propagation
        int i, count = 0;
        
        for (i = 0; i < MAX_ROUTES; i++) {
            if (linkStateDB[i].valid) {
                count++;
            }
        }
        
        // LSA Database listing removed for cleaner logs
    }
    
    command void LinkState.printRoutingTable() {
        int i;
        for (i = 0; i < MAX_ROUTES; i++) {
            if (routingTable[i].valid) {
                printRouteEntry(&routingTable[i]);
            }
        }
    }
    
    // TIMER EVENTS
    
    event void LSATimer.fired() {
        ticks += 3000;  // Match the actual timer period
        
        ageLSAs();
        cleanupFailedNodes();
        generateLSA();
        
        // Schedule routing calculation after LSA generation
        call CalculationTimer.startOneShot(1000);
    }
    
    event void CalculationTimer.fired() {
        // Don't increment ticks here - only in LSATimer
        post calculateRoutingTable();
    }
    
    // NEIGHBOR DISCOVERY EVENTS
    
    event void NeighborDiscover.neighborsChanged() {
        int i, j;
        uint16_t* currentNeighbors;
        uint8_t numCurrentNeighbors;
        bool changed = FALSE;
        uint32_t age;
        
        neighborsChanged = TRUE;
        
        // Get current neighbor list
        currentNeighbors = call NeighborDiscover.getNeighbors();
        numCurrentNeighbors = call NeighborDiscover.getNumNeighbors();
        
        // Immediately remove LSAs for nodes no longer in neighbor list
        if (currentNeighbors != NULL) {
            for (i = 0; i < MAX_ROUTES; i++) {
                if (linkStateDB[i].valid && linkStateDB[i].sourceNode != TOS_NODE_ID) {
                    bool stillNeighbor = FALSE;
                    
                    // Check if this node is still in our neighbor list
                    for (j = 0; j < numCurrentNeighbors; j++) {
                        if (currentNeighbors[j] == linkStateDB[i].sourceNode) {
                            stillNeighbor = TRUE;
                            break;
                        }
                    }
                    
                    // Check if this was recently a direct neighbor that's now gone
                    age = ticks - linkStateDB[i].timestamp;
                    // Remove LSAs for nodes that we can no longer reach directly
                    // Only remove if it was very recently updated (likely from direct neighbor)
                    if (!stillNeighbor && age < 30000) {  // Recently updated LSA from now-failed neighbor
                        addFailedNode(linkStateDB[i].sourceNode);  // Track this as a recently failed neighbor
                        linkStateDB[i].valid = FALSE;
                        changed = TRUE;
                    }
                }
            }
        }
        
        generateLSA();
        
        // Immediate routing table recalculation
        call CalculationTimer.startOneShot(100);
        
        // Clean up stale LSAs
        cleanupStaleLSAs();
        
        if (changed) {
            post calculateRoutingTable();
        }
    }
    
    // UTILITY FUNCTIONS
    
    void printRouteEntry(RouteEntry* entry) {
        dbg(GENERAL_CHANNEL, "ROUTE: %hu -> nextHop=%hu, cost=%hu\n", 
            entry->destination, entry->nextHop, entry->cost);
    }
    
    void addFailedNode(uint16_t nodeId) {
        int i;
        
        // Check if already in list
        for (i = 0; i < numFailedNodes; i++) {
            if (recentlyFailedNodes[i] == nodeId) {
                failureTimestamps[i] = ticks;  // Update timestamp
                return;
            }
        }
        
        // Add new failed node if space available
        if (numFailedNodes < MAX_NEIGHBORS_PER_LS_PACKET) {
            recentlyFailedNodes[numFailedNodes] = nodeId;
            failureTimestamps[numFailedNodes] = ticks;
            numFailedNodes++;
        }
    }
    
    bool isRecentlyFailedNode(uint16_t nodeId) {
        int i;
        for (i = 0; i < numFailedNodes; i++) {
            if (recentlyFailedNodes[i] == nodeId) {
                // Consider recently failed if within last 60 seconds
                return (ticks - failureTimestamps[i] < 60000);
            }
        }
        return FALSE;
    }
    
    void cleanupFailedNodes() {
        int i, j;
        for (i = 0; i < numFailedNodes; i++) {
            // Remove entries older than 60 seconds
            if (ticks - failureTimestamps[i] >= 60000) {
                // Shift remaining entries down
                for (j = i; j < numFailedNodes - 1; j++) {
                    recentlyFailedNodes[j] = recentlyFailedNodes[j + 1];
                    failureTimestamps[j] = failureTimestamps[j + 1];
                }
                numFailedNodes--;
                i--;  // Check this position again
            }
        }
    }
}