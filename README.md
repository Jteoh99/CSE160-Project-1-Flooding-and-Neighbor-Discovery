# Introduction
This skeleton code is the basis for the CSE160 network project. Additional documentation
on what is expected will be provided as the school year continues.

````markdown
# Introduction
This skeleton code is the basis for the CSE160 network project. Additional documentation
on what is expected will be provided as the school year continues.

# General Information
## Data Structures
There are two data structures included into the project design to help with the
assignment. See dataStructures/interfaces/ for the header information of these
structures.

* **Hashmap** - This is for anything that needs to retrieve a value based on a key.

* **List** - The list is design to have pushfront, pushback capabilities. For the most part,
you can stick with an array or even a QueueC (FIFO) which are more robust.

## General Libraries
/lib/interfaces

* **CommandHandler** - CommandHandler is what interfaces with TOSSIM. Commands are
sent to this function, and based on the parameters passed, an event is fired.
* **SimpleSend** - This is a wrapper of the lower level sender in TinyOS. The features
included is a basic queuing mechanism and some small delays to prevent collisions. Do
not change the delays. You can duplicate SimpleSendC to use a different AM type or
possibly rewire it.
* **Transport** - There is only the interface of Transport included. The actual
implementation of the Transport layer is left to the student as an exercise. For
CSE160 this will be Project 3 so don't worry about it now.

## Noise
/noise/

This is the "noise" of the network. A heavy noised network will cause issues with
packet loss.

* **no_noise.txt** - There should be no packet loss using this model.

## Topography
/topo/

This folder contains a few example topographies of the network and how they are
connected to each other. Be sure to try additional networks when testing your code
since additional ones will be added when grading.

* **long_line.topo** - this topography is a line of 19 motes that have bidirectional
links.
* **example.topo** - A slightly more complex connection

Each line has three values, the source node, the destination node, and the gain.
For now you can keep the gain constant for all of your topographies. A line written
as ```1 2 -53``` denotes a one-way connection from 1 to 2. To make it bidirectional
include also ```2 1 -53```.

# Running Simulations
The following is an example of a simulation script.
```
from TestSim import TestSim

def main():
    # Get simulation ready to run.
    s = TestSim();

    # Before we do anything, lets simulate the network off.
    s.runTime(1);

    # Load the the layout of the network.
    s.loadTopo("long_line.topo");

    # Add a noise model to all of the motes.
    s.loadNoise("no_noise.txt");

    # Turn on all of the sensors.
    s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);

    # After sending a ping, simulate a little to prevent collision.
    s.runTime(1);
    s.ping(1, 2, "Hello, World");
    s.runTime(1);

    s.ping(1, 10, "Hi!");
    s.runTime(1);

if __name__ == '__main__':
    main()
```

## Build the application from scratch

This section shows how to set up the environment, generate the Python message bindings used by TOSSIM, run the simulator, and build/flash the TinyOS application onto real motes. There are two common environments on Windows machines:

- Native Windows with TinyOS installed (less common)
- WSL (Windows Subsystem for Linux) — recommended because TinyOS tooling and toolchains are easier to install in Linux

1) Prerequisites

- TinyOS (2.x) and TOSSIM installed. Follow TinyOS docs for your OS. On WSL/Ubuntu the packages you typically need are: make, gcc, msp430-gcc toolchain (for TelosB), python (python2 or python3 depending on TOSSIM), and nesC/nesc tools. If you're using a TinyOS VM, those are preinstalled.
- Java and ant (some TinyOS installs require them for building components)
- Access to serial/USB device for flashing (e.g., /dev/ttyUSB0 in WSL or COM3 on Windows)

2) Generate Python bindings (messages) used by TestSim/TOSSIM

The project provides `includes/CommandMsg.h` and `includes/packet.h`. The Makefile contains convenient targets to generate Python bindings. From the project root run:

PowerShell (if TinyOS tools available in PATH):
```powershell
make bindings
```

WSL / Linux:
```bash
make bindings
```

If `make` isn't available, run the nescc-mig commands directly (adjust paths if needed):

PowerShell example:
```powershell
# generate bindings directly
nescc-mig python -python-classname=CommandMsg includes/CommandMsg.h CommandMsg -o CommandMsg.py
nescc-mig python -python-classname=pack includes/packet.h pack -o packet.py
```

3) Run the simulator (TOSSIM)

After generating bindings, run `TestSim.py`. Make sure to use the Python interpreter that has TOSSIM installed. If your TOSSIM uses Python 2, use `python2`.

PowerShell:
```powershell
python TestSim.py
# or
python2 TestSim.py
```

WSL / Linux:
```bash
python TestSim.py
# or
python2 TestSim.py
```

`TestSim.py` will load `topo/long_line.topo` and `noise/no_noise.txt` by default (see the script). It boots nodes, registers debug channels, and issues example pings.

4) Build for a real mote (example: TelosB)

TinyOS uses `make <target>` to build for hardware. Replace `telosb` below with your actual target (e.g., `micaz` if you're using MicaZ motes).

PowerShell / WSL:
```bash
# clean and build for telosb
make clean
make telosb

# find your serial device (Windows: COMx, WSL: /dev/ttyUSB0). Then flash:
# Example (WSL):
make telosb install bsl,/dev/ttyUSB0

# On Windows native, you may need a different install syntax or use a specific flasher tool
```

Notes:
- Ensure the MSP430 toolchain (msp430-gcc) is installed for TelosB builds.
- If the install step fails because the device is not found, check `dmesg` (WSL) or Device Manager (Windows) for the USB serial port.
- You may need to add your user to the `dialout` group on Linux: `sudo usermod -aG dialout $USER` and re-login.

5) Quick verification steps

- Simulator: When `TestSim.py` runs you should see console output such as "Creating Topo!", "Creating noise model for X", "Booted", "Radio On", and debug messages about packets and pings.
- Real mote: after flashing, open a serial terminal to the mote's serial port at the correct baud (TinyOS motes typically use 115200 or 57600). You should see debug prints matching the `dbg(...)` calls in `Node.nc`.

6) Troubleshooting

- "No module named TOSSIM": the Python you invoked doesn't have TOSSIM installed — try `python2` or use the interpreter that ships with TinyOS/TOSSIM.
- "nescc-mig: command not found": nesC / TinyOS environment not set up. Install TinyOS or use the TinyOS VM / WSL installation instructions.
- Permission denied flashing device: add your user to `dialout` (Linux) or run the flasher with appropriate permissions. On Windows ensure the serial driver for the programmer is installed.
- Wrong message bindings / Attribute errors: delete `CommandMsg.py` and `packet.py` and re-run `make bindings` to regenerate.

If you want, I can add an `install-telosb` Makefile target that wraps a typical install command for your platform (Windows vs WSL). Tell me which platform and mote model you use and I'll add it.

````

## Project objectives and implementation notes

Objectives
- Flooding: Each node must forward (flood) packets to its neighbors until the packet reaches the final destination. Flooding must support both pings and ping replies. You must only rely on information contained in the packet (headers, src/dest/seq/TTL fields) to make forwarding decisions.
- Neighbor Discovery: Each node must discover and maintain a view of its neighbors using only the existing packet types (no new packet type). The neighbor table should age out entries for nodes that drop out.

Required debug channels
- `FLOODING_CHANNEL` — use this channel for any send/receive logging related to flooding. Print a short line whenever you receive, forward or send a flooding packet showing: src, dest, node-id (this node) and the action (recv/forward/send).
- `NEIGHBOR_CHANNEL` — use this channel for neighbor discovery messages and neighbor table dumps. When a command packet triggers a neighbor dump, print the neighbor list on this channel.

Module contracts (brief)
- NeighborDiscovery module
    - Commands:
        - `findNeighbors()` — actively probe (if needed) or process recent packets to refresh neighbor table.
        - `printNeighbors()` — output the current neighbor table on `NEIGHBOR_CHANNEL`.
    - State / Outputs:
        - Maintains a neighbor table (node id -> last-seen timestamp, optional link quality)
    - Edge cases:
        - If no packets seen, `findNeighbors()` returns an empty table.
        - Implement aging: remove neighbor entries older than X ms (choose a reasonable default like 30s in simulation ticks).

- Flooding module
    - Inputs/Events:
        - listens for incoming packets (from `Receive` or a higher-level `CommandHandler.ping` event) and decides whether to forward.
    - Behavior:
        - If received packet.dest == this node: deliver locally (debug via `FLOODING_CHANNEL`).
        - Else: decrement TTL (if TTL used) or check seq/src to prevent loops; forward to all neighbors except the one it was received from.
        - Use a simple duplicate suppression cache keyed by (src, seq) to avoid reforwarding the same packet multiple times.
    - Outputs:
        - Calls down to `SimpleSend.send()` for each neighbor it will forward to (or uses the node's sender interface).

Wiring example (pseudocode for a configuration file)
```
configuration NodeAppC {
    provides interface Boot;
}

implementation {
    components NodeC, NeighborDiscoverC, FloodingC, SimpleSendC, CommandHandlerC;

    // wiring
    NodeC.CommandHandler -> CommandHandlerC;
    NodeC.Sender -> SimpleSendC;
    // connect the flooding and neighbor discovery modules to Node
    NodeC -> FloodingC; // pseudocode - actual wiring depends on TinyOS interfaces you define
    NodeC -> NeighborDiscoverC;
}
```

Testing checklist (TOSSIM)
- Generate bindings and run `TestSim.py`.
- Watch channels: add `s.addChannel(s.FLOODING_CHANNEL)` and `s.addChannel(s.NEIGHBOR_CHANNEL)` in `TestSim.py` to see flooding and neighbor logs.
- Test 1: Ping from node A to node B along a path. Expect to see `FLOODING_CHANNEL` messages at each hop (recv/forward) and final delivery at B.
- Test 2: Re-send same ping (same src+seq) and verify duplicates are suppressed (no forwarding logs for repeats).
- Test 3: Power off a mote (use `moteOff()` in TestSim), then run neighbor discovery — verify the neighbor table ages out that node and `NEIGHBOR_CHANNEL` reports removal.

Implementation tips
- Keep interfaces small and modular: expose commands (actions) and events (callbacks) only for necessary operations.
- Use the repo's provided `Hashmap` and `List` data structures for neighbor tables and duplicate caches.
- Start by wiring the modules and stubbing their behavior (print debug lines) before implementing full logic.

If you'd like, I can generate a sample `NeighborDiscoverC.nc` and `FloodingC.nc` skeleton (with the correct interface signatures) and a `NodeAppC` configuration that wires them into `NodeC`. Would you like me to add those skeleton files now?

