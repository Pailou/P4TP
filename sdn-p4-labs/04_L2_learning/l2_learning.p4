/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

#define PKT_INSTANCE_TYPE_NORMAL 0
#define PKT_INSTANCE_TYPE_INGRESS_CLONE 1

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

// TODO: define ethernet_t header --> copy from previous exercise 
typedef bit<48> macAddr_t;
header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16> etherType;
}

// TODO: define a new packet_in_t header which includes an ingress_port field
// annotate with @controller_header("packet_in")

@controller_header("packet_in")
header packet_in_t {
    bit<16> ingress_port;
}
// TODO: define struct headers
struct headers {
    ethernet_t ethernet;
    packet_in_t cpu;
}

struct metadata {
    // TODO: add an ingress_port field in the user's metadata
    // annotate with @field_list(1)
    @field_list(1)
    bit<16> ingress_port;
}




/*************************************************************************
************************* P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t smeta) {

    state start {
        // TODO: parse ethernet header --> copy from previous exercise
        packet.extract(hdr.ethernet);
        transition accept;
    }

}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   **************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   ********************
*************************************************************************/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t smeta) {

    // TODO:
    // - copy forward and broadcast actions from previous exercise
    
    action forward(bit<9> egress_port) {
        smeta.egress_spec = egress_port;
    }
    action broadcast(bit<16> mcast_grp) {
        smeta.mcast_grp = mcast_grp;
    }
    // - copy dmac and mcast_grp tables from previous exercise
    table dmac {
        key = {
            hdr.ethernet.dstAddr : exact;
        }
        actions = {
            forward;
            NoAction();
            //broadcast;
        }
            //default_action = broadcast(1);
            default_action = NoAction();
    }

    table mcast_grp {
        key = {
            smeta.ingress_port: exact;
        }
        actions = {
            broadcast;
            NoAction();
        }
        default_action = broadcast(1);
    }

    // TODO: add mac_learn action, saving ingress_port and cloning packet
    action mac_learn() {
        meta.ingress_port = (bit<16>)smeta.ingress_port;
        clone_preserving_field_list(CloneType.I2E,100,1);
    }

    // TODO: add smac table to learn from source MAC address
    table smac {
        key = {
            hdr.ethernet.srcAddr: exact;
        }
        actions = {
            mac_learn;
            NoAction;
        }
        default_action = mac_learn();
    }

    apply {
        // TODO: apply smac table
        smac.apply();
        // TODO (copy from previous exercise)
        // -> apply mcast_grp table if no hit on dmac table
        if (!dmac.apply().hit) {
            mcast_grp.apply();
        }
    }

}

/*************************************************************************
*****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t smeta) {
    apply {
        // TODO: if packet is an ingress clone, add cpu header
        // (setValid and init ingress_port) 
         if (smeta.instance_type == PKT_INSTANCE_TYPE_INGRESS_CLONE) {
            hdr.cpu.setValid();
            hdr.cpu.ingress_port = meta.ingress_port;
        }
     
    }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   ***************
*************************************************************************/

control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
    apply { }
}

/*************************************************************************
***********************  D E P A R S E R  ********************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        // TODO: deparse cpu and ethernet header
        packet.emit(hdr.cpu);
        packet.emit(hdr.ethernet);
    }
}

/*************************************************************************
*************************  S W I T C H  **********************************
*************************************************************************/

V1Switch(
    MyParser(),
    MyVerifyChecksum(),
    MyIngress(),
    MyEgress(),
    MyComputeChecksum(),
    MyDeparser()
) main;
