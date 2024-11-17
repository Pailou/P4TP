/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

struct metadata {
    /* empty */
}

/* Ethernet header definition */
header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

struct headers {
    ethernet_t ethernet;
}

/*************************************************************************
************************* P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t smeta) {

    state start {
        packet.extract(hdr.ethernet); // Extract Ethernet header
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

    /* Action to forward packets to a specific port */
    action forward(bit<9> egress_port) {
        smeta.egress_spec = port;
    }

    /* Action to broadcast packets to a multicast group */
    action broadcast(bit<16> mcast_grp) {
        smeta.mcast_grp = mcast_grp;
    }

    /* dmac table: Matches destination MAC and triggers forward or broadcast */
    table dmac {
        key = {
            hdr.ethernet.dstAddr: exact;
        }
        actions = {
            forward;
            NoAction;
        }
        default_action = NoAction();
    }

    /* mcast_grp table: Matches ingress port and triggers broadcast */
    table mcast_grp {
        key = {
            smeta.ingress_port: exact;
        }
        actions = {
            broadcast;
            NoAction;
        }
        size = 8;
        default_action = NoAction();
    }

    apply {
        // Apply dmac table
        if (!dmac.apply().hit) {
            // If no match in dmac, apply mcast_grp for broadcast
            mcast_grp.apply();
        }
    }

}

/*************************************************************************
*****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { }
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
        packet.emit(hdr.ethernet); // Deparse Ethernet header
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
