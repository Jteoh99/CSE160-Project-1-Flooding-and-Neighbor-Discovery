#ANDES Lab - University of California, Merced
#Author: UCM ANDES Lab
#$Author: abeltran2 $
#$LastChangedDate: 2014-08-31 16:06:26 -0700 (Sun, 31 Aug 2014) $
#! /usr/bin/python
import sys
from TOSSIM import *
from CommandMsg import *

class TestSim:
    moteids=[]
    # COMMAND TYPES
    CMD_PING = 0
    CMD_NEIGHBOR_DUMP = 1
    CMD_LINKSTATE_DUMP = 2
    CMD_ROUTE_DUMP=3

    # CHANNELS - see includes/channels.h
    COMMAND_CHANNEL="command";
    GENERAL_CHANNEL="general";

    # Project 1
    NEIGHBOR_CHANNEL="neighbor";
    FLOODING_CHANNEL="flooding";

    # Project 2
    ROUTING_CHANNEL="routing";

    # Project 3
    TRANSPORT_CHANNEL="transport";

    # Personal Debuggin Channels for some of the additional models implemented.
    HASHMAP_CHANNEL="hashmap";

    # Initialize Vars
    numMote=0

    def __init__(self):
        self.t = Tossim([])
        self.r = self.t.radio()

        #Create a Command Packet
        self.msg = CommandMsg()
        self.pkt = self.t.newPacket()
        self.pkt.setType(self.msg.get_amType())

    # Load a topo file and use it.
    def loadTopo(self, topoFile):
        print 'Creating Topo!'
        # Read topology file.
        topoFile = 'topo/'+topoFile
        f = open(topoFile, "r")
        self.numMote = int(f.readline());
        print 'Number of Motes', self.numMote
        for line in f:
            s = line.split()
            if s:
                # print " ", s[0], " ", s[1], " ", s[2];  # Comment out for cleaner output
                self.r.add(int(s[0]), int(s[1]), float(s[2]))
                if not int(s[0]) in self.moteids:
                    self.moteids=self.moteids+[int(s[0])]
                if not int(s[1]) in self.moteids:
                    self.moteids=self.moteids+[int(s[1])]

    # Load a noise file and apply it.
    def loadNoise(self, noiseFile):
        if self.numMote == 0:
            print "Create a topo first"
            return;

        # Get and Create a Noise Model
        noiseFile = 'noise/'+noiseFile;
        noise = open(noiseFile, "r")
        for line in noise:
            str1 = line.strip()
            if str1:
                val = int(str1)
            for i in self.moteids:
                self.t.getNode(i).addNoiseTraceReading(val)

        for i in self.moteids:
            # print "Creating noise model for ",i;  # Comment out for cleaner output
            self.t.getNode(i).createNoiseModel()

    def bootNode(self, nodeID):
        if self.numMote == 0:
            print "Create a topo first"
            return;
        self.t.getNode(nodeID).bootAtTime(1333*nodeID);

    def bootAll(self):
        i=0;
        for i in self.moteids:
            self.bootNode(i);

    def moteOff(self, nodeID):
        self.t.getNode(nodeID).turnOff();

    def moteOn(self, nodeID):
        self.t.getNode(nodeID).turnOn();

    def run(self, ticks):
        for i in range(ticks):
            self.t.runNextEvent()

    # Rough run time. tickPerSecond does not work.
    def runTime(self, amount):
        self.run(amount*1000)

    # Generic Command
    def sendCMD(self, ID, dest, payloadStr):
        self.msg.set_dest(dest);
        self.msg.set_id(ID);
        self.msg.setString_payload(payloadStr)

        self.pkt.setData(self.msg.data)
        self.pkt.setDestination(dest)
        self.pkt.deliver(dest, self.t.time()+5)

    def ping(self, source, dest, msg):
        self.sendCMD(self.CMD_PING, source, "{0}{1}".format(chr(dest),msg));

    def neighborDMP(self, destination):
        self.sendCMD(self.CMD_NEIGHBOR_DUMP, destination, "neighbor command");

    def cmdRouteDMP(self, destination):
        # Command to print routing table
        self.sendCMD(self.CMD_ROUTE_DUMP, destination, "routing command");

    def linkStateDMP(self, destination):
        self.sendCMD(self.CMD_LINKSTATE_DUMP, destination, "linkstate command");

    def routeDMP(self, destination):
        # Alias for cmdRouteDMP to match expected function name
        self.sendCMD(self.CMD_ROUTE_DUMP, destination, "routing command");

    def addChannel(self, channelName, out=sys.stdout):
        # print 'Adding Channel', channelName;  # Comment out for cleaner output
        self.t.addChannel(channelName, out);

def main():
    s = TestSim();
    s.runTime(10);
    s.loadTopo("circle.topo");
    s.loadNoise("no_noise.txt");
    s.bootAll();
    s.addChannel(s.COMMAND_CHANNEL);
    s.addChannel(s.GENERAL_CHANNEL);

    print("Initializing network")
    print("Number of Motes:", s.numMote)

    # Network initialization
    print("\nNeighbor Discovery")
    s.runTime(20);
    
    print("Link-State Convergence")
    s.runTime(300);

    # Test sequence as requested
    print("\nTest Sequence")
    
    print("1. Show routing table for Node 18:")
    s.cmdRouteDMP(18);
    s.runTime(5);
    
    print("\n2. Ping from Node 18 to Node 1:")
    s.ping(18, 1, "Test ping");
    s.runTime(300);
    
    print("\n3. Failing Node 19:")
    s.moteOff(19);
    s.runTime(300);  # Allow failure detection
    
    print("\n4. Ping from Node 2 to Node 17 (after Node 9 failure):")
    s.ping(2, 17, "Post-failure ping");
    s.runTime(300);
    
    print("\n5. Show routing table for Node 2:")
    s.routeDMP(2);
    s.runTime(5);
    
    print("\nTest Complete")


    '''
    # Test 1: Basic optimal routing before any failures
    print("\n=== TEST 1: Pre-failure optimal routing ===")
    s.routeDMP(18);  
    s.runTime(2);
    
    print("Test: Node 18 -> Node 1 (optimal path)")
    s.ping(18, 1, "Optimal path test");
    s.runTime(60);  # Extended time for complete packet delivery
    
    print("Waiting for network to stabilize...")
    s.runTime(30);  # Stabilization period
    
    # Test 2: Multiple hops test
    print("\n=== TEST 2: Multi-hop routing ===")
    print("Test: Node 18 -> Node 9 (multi-hop)")
    s.ping(18, 9, "Multi-hop test");
    s.runTime(180);  # Much longer time for 9-hop round trip (18 total hops)
    
    print("Waiting for network to stabilize...")
    s.runTime(30);  # Stabilization period
    
    print("Test: Node 1 -> Node 10 (multi-hop)")
    s.ping(1, 10, "Multi-hop test reverse");
    s.runTime(180);  # Much longer time for 9-hop round trip (18 total hops)
    
    print("Waiting for all packets to complete before failure test...")
    s.runTime(60);  # Extended pre-failure wait
    
    # Fault Tolerance
    print("\n=== FAULT TOLERANCE TEST 1: Single Node Failure (Node 19) ===")
    s.moteOff(19);
    print("Allowing extended time for complete failure detection cycle...")
    s.runTime(180);  # Much longer convergence time for neighbor timeout + LSA aging + routing recalculation
    
    print("Additional time for routing table stabilization...")
    s.runTime(60);   # Extra stabilization after failure detection
    
    print("\nNode 18 routing table after Node 19 failure:")
    s.routeDMP(18);
    s.runTime(2);
    
    print("\nNode 17 routing table after Node 19 failure:")
    s.routeDMP(17);
    s.runTime(2);
    
    print("\nNode 1 routing table after Node 19 failure:")
    s.routeDMP(1);
    s.runTime(2);
    
    print("\nDetailed LSA database analysis:")
    print("Node 17 LSA database after Node 19 failure:")
    s.linkStateDMP(17);
    s.runTime(2);
    
    print("\nNode 18 LSA database after Node 19 failure:")
    s.linkStateDMP(18);
    s.runTime(2);
    
    print("\nNode 1 LSA database after Node 19 failure:")
    s.linkStateDMP(1);
    s.runTime(2);
    
    # Test 3: Failover routing after Node 19 failure
    print("\n=== TEST 3: Failover routing after Node 19 failure ===")
    print("Test: Node 18 -> Node 1 (should use 17-hop path)")
    s.ping(18, 1, "Failover path test");
    s.runTime(60);  # Extended time for long alternate path
    
    print("Waiting for complete packet delivery...")
    s.runTime(30);  # Separation time
    
    print("\nTest: Node 1 -> Node 18 (reverse failover)")
    s.ping(1, 18, "Reverse failover test");
    s.runTime(60);  # Extended time
    
    print("Waiting for complete packet delivery...")
    s.runTime(30);  # Separation time
    
    # Test 4: Additional routing tests to verify no loops
    print("\n=== TEST 4: Loop detection tests ===")
    print("Test: Node 17 -> Node 1 (should work without loops)")
    s.ping(17, 1, "Direct routing test");
    s.runTime(60);  # Extended time
    
    print("Waiting for complete packet delivery...")
    s.runTime(30);  # Separation time
    
    print("Test: Node 16 -> Node 2 (cross-topology routing)")
    s.ping(16, 2, "Cross-topology test");
    s.runTime(60);  # Extended time
    
    # ================= DOUBLE FAILURE TESTS =================
    print("\n=== FAULT TOLERANCE TEST 2: Double Node Failure ===")
    print("Waiting for complete stabilization before double failure...")
    s.runTime(60);  # Pre-failure stabilization
    
    print("Failing Node 2 (in addition to Node 19)")
    s.moteOff(2);
    print("Allowing extended time for double failure detection...")
    s.runTime(180);  # Extended convergence for double failure
    
    print("Additional stabilization time...")
    s.runTime(60);   # Extra stabilization
    
    print("\nRouting tables after double failure:")
    s.routeDMP(18);
    s.runTime(2);
    s.routeDMP(17);
    s.runTime(2);
    s.routeDMP(1);
    s.runTime(2);
    s.routeDMP(3);
    s.runTime(2);
    
    print("\nTest: Node 18 -> Node 3 (with double failure)")
    s.ping(18, 3, "Double failure test");
    s.runTime(10);
    
    # ================= RECOVERY TESTS =================
    print("\n=== RECOVERY TEST: Node restoration ===")
    print("Restoring Node 19")
    s.moteOn(19);
    s.runTime(120);  # Allow full convergence and neighbor discovery
    
    print("\nPost-recovery routing tables:")
    s.routeDMP(18);
    s.runTime(2);
    s.routeDMP(19);
    s.runTime(2);
    s.routeDMP(1);
    s.runTime(2);
    
    print("\nTest: Node 18 -> Node 1 (after Node 19 recovery)")
    s.ping(18, 1, "Recovery test");
    s.runTime(10);
    
    # ================= STRESS TESTS =================
    print("\n=== STRESS TEST: Multiple rapid failures ===")
    print("Sequential failures: Node 3, Node 7, Node 11")
    s.moteOff(3);
    s.runTime(30);
    s.moteOff(7);
    s.runTime(30);
    s.moteOff(11);
    s.runTime(60);
    
    print("\nStress test routing:")
    s.routeDMP(18);
    s.runTime(2);
    s.routeDMP(1);
    s.runTime(2);
    
    print("Test: Node 18 -> Node 15 (after multiple failures)")
    s.ping(18, 15, "Stress test");
    s.runTime(15);
    
    # ================= EDGE CASE TESTS =================
    print("\n=== EDGE CASE TEST: Network partition ===")
    print("Creating network partition by failing Nodes 9 and 10")
    s.moteOff(9);
    s.moteOff(10);
    s.runTime(90);
    
    print("\nPartition test - should fail gracefully:")
    print("Test: Node 18 -> Node 5 (across partition)")
    s.ping(18, 5, "Partition test");
    s.runTime(15);
    
    print("\nWithin partition routing should still work:")
    print("Test: Node 18 -> Node 16 (within partition)")
    s.ping(18, 16, "Within partition test");
    s.runTime(10);
    
    print("\n=== FINAL DIAGNOSTICS ===")
    print("Final LSA database states:")
    s.linkStateDMP(18);
    s.runTime(2);
    s.linkStateDMP(17);
    s.runTime(2);
    s.linkStateDMP(1);
    s.runTime(2);
    
    print("\nComprehensive testing completed!")

    '''

if __name__ == '__main__':
    main()
