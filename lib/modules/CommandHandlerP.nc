/**
 * @author UCM ANDES Lab
 * $Author: abeltran2 $
 * $LastChangedDate: 2014-08-31 16:06:26 -0700 (Sun, 31 Aug 2014) $
 *
 */


#include "../../includes/CommandMsg.h"
#include "../../includes/command.h"
#include "../../includes/channels.h"

module CommandHandlerP{
   provides interface CommandHandler;
   uses interface Receive;
   uses interface Pool<message_t>;
   uses interface Queue<message_t*>;
   uses interface Packet;
}

implementation{
    task void processCommand(){
        if(! call Queue.empty()){
            CommandMsg *msg;
            uint8_t commandID;
            uint8_t* buff;
            message_t *raw_msg;
            void *payload;

            // Pop message out of queue.
            raw_msg = call Queue.dequeue();
            payload = call Packet.getPayload(raw_msg, sizeof(CommandMsg));

            // Check to see if the packet is valid.
            if(!payload){
                call Pool.put(raw_msg);
                post processCommand();
                return;
            }
            // Change it to our type.
            msg = (CommandMsg*) payload;

            // NEIGHBOR_CHANNEL requirement: notify when command packet is issued
            dbg(NEIGHBOR_CHANNEL, "COMMAND_ISSUED: Node %hu received command packet (id=%hu)\n", 
                TOS_NODE_ID, msg->id);
            buff = (uint8_t*) msg->payload;
            commandID = msg->id;

            //Find out which command was called and call related command
            switch(commandID){
            // A ping will have the destination of the packet as the first
            // value and the string in the remainder of the payload
            case CMD_PING:
                dbg(NEIGHBOR_CHANNEL, "PING_COMMAND: Node %hu executing ping to destination %hu\n", 
                    TOS_NODE_ID, buff[0]);
                signal CommandHandler.ping(buff[0], &buff[1]);
                break;

            case CMD_NEIGHBOR_DUMP:
                dbg(NEIGHBOR_CHANNEL, "NEIGHBOR_DUMP_COMMAND: Node %hu executing neighbor dump\n", 
                    TOS_NODE_ID);
                signal CommandHandler.printNeighbors();
                break;

            case CMD_LINKSTATE_DUMP:
                signal CommandHandler.printLinkState();
                break;

            case CMD_ROUTETABLE_DUMP:
                signal CommandHandler.printRouteTable();
                break;

            case CMD_TEST_CLIENT:
                signal CommandHandler.setTestClient();
                break;

            case CMD_TEST_SERVER:
                signal CommandHandler.setTestServer();
                break;

            default:
                dbg(COMMAND_CHANNEL, "CMD_ERROR: \"%d\" does not match any known commands.\n", msg->id);
                break;
            }
            call Pool.put(raw_msg);
        }

        if(! call Queue.empty()){
            post processCommand();
        }
    }
    event message_t* Receive.receive(message_t* raw_msg, void* payload, uint8_t len){
        if (! call Pool.empty()){
            call Queue.enqueue(raw_msg);
            post processCommand();
            return call Pool.get();
        }
        return raw_msg;
    }
}
