#!/usr/bin/python3

import sys
sys.path.append(".")
from TestSim import TestSim

def main():
    s = TestSim()
    s.runTime(10)
    s.loadTopo("topo/topo.txt")
    s.loadNoise("noise/no_noise.txt")
    s.bootAll()
    s.addChannel(s.COMMAND_CHANNEL)
    s.addChannel(s.GENERAL_CHANNEL)

    # Start the simulation
    s.runTime(5)
    
    # Check neighbors first
    print("=== Node 3 Neighbors ===")
    s.neighborDMP(3)
    s.runTime(3)
    
    print("\n=== Node 10 Neighbors ===")
    s.neighborDMP(10)
    s.runTime(3)
    
    # Wait for convergence
    print("\nWaiting for convergence...")
    s.runTime(15)
    
    # Check routing tables
    print("\n=== Node 3 Routing Table ===")
    s.routeDMP(3)
    s.runTime(2)

if __name__ == '__main__':
    main()