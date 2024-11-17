g/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

struct metadata {
    /* empty */
}

/* TODO 1: Define ethernet_t header and headers struct */

header ethernet_t {
    bit<48> dstAddr; // Adresse MAC de destination
    bit<48> srcAddr; // Adresse MAC source
    bit<16> etherType; // Type EtherType
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
        /* TODO 2: parse ethernet header */
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

    /* TODO 3: define an action to set smeta.egress_spec */
    action forward(bit<9> egress_port) {
        smeta.egress_spec = port;
    }

    /* TODO 4: define a dmac table that can trigger the previous action */
    /* (default action will be NoAction defined in core.p4) */
    table dmac {
    key = {
        hdr.ethernet.dstAddr: exact;
    }
    actions = {
        forward;
        NoAction;
    }
    size = 1024;
    default_action = NoAction();
}

    apply {
        /* TODO 5: apply the dmac table */
        dmac.apply();
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
        /* TODO 6: deparse ethernet header */
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
