#!/usr/bin/python
from TestSim import TestSim

def main():
    # Create a test simulation environment
    s = TestSim()
    
    # Load the topology
    s.loadTopo("long_line.topo")
    
    # Boot all nodes
    s.bootAll()
    s.addChannel(s.COMMAND_CHANNEL)
    s.addChannel(s.GENERAL_CHANNEL)
    
    print("Link-State Convergence Test")
    print("==========================")
    
    # Wait for extensive convergence
    print("\nPhase 1: Network initialization and convergence (120 seconds)")
    s.runTime(120)
    
    print("\nPhase 2: Topology verification")
    print("==============================")
    
    # Check multiple nodes' routing tables and LSA databases
    for nodeId in [1, 5, 8]:
        print(f"\n=== Node {nodeId} Complete Status ===")
        print(f"Node {nodeId} Routing Table:")
        s.routeDump(nodeId)
        s.runTime(1)
        
        print(f"Node {nodeId} LSA Database:")
        s.linkStateDMP(nodeId)
        s.runTime(1)
    
    print("\nPhase 3: Routing tests with complete topology")
    print("=============================================")
    
    # Test routing between various nodes
    test_pairs = [(1, 8), (5, 1), (8, 5)]
    
    for src, dest in test_pairs:
        print(f"\n=== Test: Node {src} -> Node {dest} ===")
        s.routeDump(src)
        s.runTime(1)
        s.ping(src, dest, f"Test from {src} to {dest}")
        s.runTime(3)
    
    print("\nTesting completed!")

if __name__ == '__main__':
    main()