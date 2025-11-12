interface NeighborDiscover{
    command void findNeighbors();
    command void printNeighbors();
    command void receive(pack* msg);
    command uint16_t* getNeighbors();
    command uint8_t getNumNeighbors();
    
    // Event signaled when neighbor list changes
    event void neighborsChanged();
}