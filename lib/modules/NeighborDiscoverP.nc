#include <Timer.h>

generic module NeighborDiscoverP() {
    provides interface NeighborDiscover;
    uses interface Timer<TMilli> as neighborTimer;
    uses interface Random;
    uses interface SimpleSend;
}

implementation {
    command void NeighborDiscover.findNeighbors() {
        call neighborTimer.startOneShot((call Random.rand16() % 300) + 100);
        dbg(GENERAL_CHANNEL, "NeighborDiscover.findNeighbors() called\n");
    }

    task void search() {
        // Logic to send out a beacon to find neighbors
        // If someone responds, add them to a table
        call neighborTimer.startPeriodic((call Random.rand16() % 300) + 100);
    }

    event void neighborTimer.fired() {
        post search();
    }

    command void NeighborDiscover.printNeighbors() {

    }
}