#include <Timer.h>

generic module NeighborDiscoveryP(){
    provides interface NeighborDiscovery;

    uses interface Timer<TMilli> as neighborTimer;
    uses interface Random;
}

implementation {
    command void NeighborDiscovery.findNeighbors() {
        call neighborTimer.startOneShot((call Random.rand16() % 300) + 100);
    }

    task void search() {
        "logic to send out a beacon to find neighbors"
        "if someone responds, add them to a table"
        call neighborTimer.startPeriodic((call Random.rand16() % 300) + 100);
    }

    event void neighborTimer.fired() {
        post search();
    }

    command void NeighborDiscovery.printNeighbors() {

    }
}