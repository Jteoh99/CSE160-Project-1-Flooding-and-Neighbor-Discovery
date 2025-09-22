Module wiring guide
=====================

This guide walks through creating and wiring the Neighbor Discovery and Flooding modules, step-by-step. It assumes the repo layout in this workspace and that you want modules under `lib/modules/` (or you can put them under `modules/` but keep include paths consistent).

Goal
----
- Neighbor discovery: discover neighbors using existing packets; maintain a neighbor table and age out entries.
- Flooding: receive packets and forward them to neighbors until they reach destination. Use duplicate suppression.

Quick overview
--------------
1. Create module implementations: `FloodingP.nc` (module implementation) and `FloodingC.nc` (configuration wrapper), and ensure `NeighborDiscoverP.nc` / `NeighborDiscoverC.nc` are wired and used by `NodeAppC.nc`.
2. Wire `SimpleSend` (already available as `SimpleSendC`) to be used by both modules to actually send packets.
3. Use `FLOODING_CHANNEL` and `NEIGHBOR_CHANNEL` (defined in `includes/channels.h`) for all debug prints.
4. Test in TOSSIM and iterate.

Where to put files
------------------
- App-level wiring: `NodeAppC.nc` in the repo root (replace/modify the existing one; currently empty in this repo).
- Module implementations: `lib/modules/FloodingP.nc` and `lib/modules/FloodingC.nc` (this repo already has NeighborDiscoverP and NeighborDiscoverC). If you prefer, `modules/` is fine too.

Step-by-step: create Flooding module (skeleton)
----------------------------------------------
1) Create `lib/modules/FloodingC.nc` (configuration wrapper)

Example `FloodingC.nc` (put in `lib/modules/FloodingC.nc`):

```nesc
#include "../../includes/am_types.h"

generic configuration FloodingC(int channel) {
  provides interface Flooding;
}

implementation {
  components new FloodingP();
  Flooding = FloodingP.Flooding;

  // Attach a Timer to the implementation if needed
  components new TimerMilliC() as floodTimer;
  FloodingP.floodTimer -> floodTimer;

  // Use the project's SimpleSend component to actually send packets
  components SimpleSendC(channel);
  FloodingP.SimpleSend -> SimpleSendC;
}
```

2) Create `lib/modules/FloodingP.nc` (module implementation skeleton)

Example `FloodingP.nc` (put in `lib/modules/FloodingP.nc`):

```nesc
#include <Timer.h>
#include "../../includes/channels.h"
#include "../../includes/packet.h"

module FloodingP() {
  provides interface Flooding;

  uses interface Receive;
  uses interface SimpleSend; // provided by SimpleSendC
  uses interface Timer<TMilli> as floodTimer;
}

implementation {
  // A simple duplicate suppression cache (use provided Hashmap or List) -- pseudo
  // hashmap: key=(src<<16)|seq -> lastSeen

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    dbg(FLOODING_CHANNEL, "Packet Received by %d\n", TOS_NODE_ID);
    // Validate packet size and cast
    if (len >= sizeof(pack)) {
      pack* p = (pack*)payload;
      // If dest is this node -> deliver locally
      if (p->dest == TOS_NODE_ID) {
        dbg(FLOODING_CHANNEL, "Delivering packet at %d from %d\n", TOS_NODE_ID, p->src);
        return msg;
      }

      // Duplicate suppression: check cache for (p->src, p->seq)
      // If seen, ignore; else add to cache and forward

      // Forwarding: call SimpleSend.send() for neighbors (SimpleSend may queue and send to a destination address)
      dbg(FLOODING_CHANNEL, "Forwarding packet at %d (to neighbors)\n", TOS_NODE_ID);
      // Example: call SimpleSend.send(p, destNode);
    }
    return msg;
  }

  event void floodTimer.fired() {
    // Optional: periodic maintenance (expire cache entries / neighbor table)
  }

  // Provide no-op commands for the interface until you add more
  command void Flooding.someCommand() {
    // stub
  }
}
```

Notes:
- Replace `someCommand` with real commands if you want the Flooding interface to expose actions. The main work is inside `Receive.receive`.
- Use `dbg(FLOODING_CHANNEL, ...)` for the logging the instructors expect.

Neighbor discovery notes
------------------------
- This repo already contains `lib/modules/NeighborDiscoverP.nc` and `NeighborDiscoverC.nc`. The provided `NeighborDiscoverP` uses a timer and a `search` task stub. Use that file as your starting point.
- Strategy: piggyback neighbor discovery on normal traffic. Any packet received from node X means X is a neighbor; update neighbor table with timestamp. To actively probe, you can use `SimpleSend` to transmit a small command-style packet (but requirements said avoid new packet types — you can reuse the command packet format already present in the project).

Example neighbor table entry (in C-like pseudocode):
```
struct NeighborEntry {
  uint16_t id;
  uint32_t lastSeen; // simulation ticks or a counter
  int rssi; // optional
};
```

When you receive any packet, call into `NeighborDiscovery` (or have Flooding update the neighbor table directly) with `updateNeighbor(src)`.

`NeighborDiscoveryP` already exposes `findNeighbors()` and `printNeighbors()` commands. Implement `findNeighbors` to start a one-shot timer (already done) and implement `printNeighbors` to iterate your neighbor table and `dbg(NEIGHBOR_CHANNEL, ...)` each neighbor.

Wiring everything into the application
-------------------------------------
- Create an app configuration `NodeAppC.nc` (replace the empty one in the repo root) that wires the Node and modules together. Example file:

```nesc
configuration NodeAppC {
  provides interface Boot;
}

implementation {
  components NodeC, NeighborDiscoveryC(0), FloodingC(0), SimpleSendC(0), CommandHandlerC;

  // Wire Node's interfaces to the modules
  NodeC.CommandHandler -> CommandHandlerC;
  NodeC.Sender -> SimpleSendC;

  // You may need to wire Receive/SplitControl depending on NodeC's provided/used interfaces
  // Example: expose Flooding and Neighbor modules so NodeC can call them if needed
  // NodeC.Flooding -> FloodingC.Flooding;
  // NodeC.NeighborDiscovery -> NeighborDiscoveryC.NeighborDiscovery;

  Boot = NodeC;
}
```

Adjust the channel numbers (the `0` in `FloodingC(0)`) to match the Active Message type/channel you want. The project's `Makefile` and `includes/am_types.h` define AM types.

Testing checklist
-----------------
1. make bindings
2. python TestSim.py (or use `make sim` if available)
3. In `TestSim.py`, add these channels so you can see logs:
   - `s.addChannel(s.FLOODING_CHANNEL)`
   - `s.addChannel(s.NEIGHBOR_CHANNEL)`
4. Test a ping from node 1 to node 3 and watch that each hop prints `FLOODING_CHANNEL` messages (recv/forward) and final delivery.
5. Test neighbor discovery by issuing a neighbor dump command (implement a function in `TestSim` to deliver a CommandMsg that triggers `CommandHandler.printNeighbors()`), then watch `NEIGHBOR_CHANNEL` for output.

Extra tips and recommended steps
--------------------------------
- Start small: get the skeleton module wired and print a debug message in `Boot.booted()` or in a `post init()` call to confirm wiring is correct.
- Use the provided data structures in `dataStructures/` (Hashmap/List) to implement neighbor table and duplicate cache.
- Keep duplicate suppression simple: store last N (src, seq) tuples in a hashmap with timestamps.

Do you want me to:
- generate `lib/modules/FloodingP.nc` and `lib/modules/FloodingC.nc` skeleton files automatically in the repo? (I can create them as basic placeholders with the code above), or
- create a concrete `NodeAppC.nc` file and wire everything for you?

If yes to either, tell me which option and I will create those files. 
