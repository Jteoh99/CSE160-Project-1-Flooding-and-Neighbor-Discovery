#!/usr/bin/python3

import TestSim

def main():
    # Quick debug test to check LSDB contents
    t = TestSim.TestSim()
    t.setTestDir("topoTest")
    t.loadTopo("topo/ring19.topo")
    t.addChannel(s.GENERAL_CHANNEL)

    # Start simulation
    t.bootAll()
    t.addTime(20000)  # 20 seconds for neighbor discovery
    t.addTime(30000)  # 30 seconds for LSA propagation
    
    # Check LSDB contents for Node 18
    print("=== LSDB Debug Test ===")
    t.runTime(1000)
    
    # Force a routing table calculation to see debug output
    t.testLinkState(18)
    t.runTime(1000)

if __name__ == '__main__':
    main()