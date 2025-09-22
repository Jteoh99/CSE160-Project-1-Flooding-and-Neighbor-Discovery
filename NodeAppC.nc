configuration NodeAppC {
	provides interface Boot;
}

implementation {
	components MainC, NodeC, CommandHandlerC;

	// NodeC already wires its own SimpleSend(AM_PACK) and Receive for AM_PACK
	// We will attach Flooding on a separate AM type (AM_FLOODING)
	components new AMReceiverC(AM_FLOODING) as FloodingReceive;

	// Instantiate Flooding and NeighborDiscovery modules
	components FloodingC(AM_FLOODING);
	components NeighborDiscoveryC(AM_PACK);

	// Wire Flooding receive to the AM receiver for the flooding AM type
	FloodingC.Receive -> FloodingReceive;

	// Boot comes from NodeC
	Boot = NodeC;

	// Wire NodeC to CommandHandlerC and let NodeC keep its existing Sender binding
	NodeC.CommandHandler -> CommandHandlerC;
}
