/**
 * LinkState interface
 * Provides link-state routing functionality for building and maintaining routing tables
 */

interface LinkState {
    // Initialize link-state routing
    command void start();
    
    // Stop link-state routing
    command void stop();
    
    // Process received link-state packets
    command void receive(void* msg);
    
    // Update routing table when neighbor list changes
    command void updateLinkState();
    
    // Get next hop for a destination using routing table
    command uint16_t getNextHop(uint16_t destination);
    
    // Check if we have a valid route to destination
    command bool hasRoute(uint16_t destination);
    
    // Print link-state advertisements and routing table
    command void printLinkState();
    command void printRoutingTable();
    
    // Route a packet using link-state routing table
    command error_t route(void* packet, uint16_t nextHop);
}