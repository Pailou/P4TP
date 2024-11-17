/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

#define PKT_INSTANCE_TYPE_NORMAL 0
#define PKT_INSTANCE_TYPE_INGRESS_CLONE 1

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

// TODO: define ethernet_t header --> copy from previous exercise 
header ethernet_t {
    bit<48> dstAddr;  // Adresse MAC destination
    bit<48> srcAddr;  // Adresse MAC source
    bit<16> etherType; // Type Ethernet
}

// TODO: define a new packet_in_t header which includes an ingress_port field
// annotate with @controller_header("packet_in")
@controller_header("packet_in")
header packet_in_t {
    bit<9> ingress_port;  // Port d'entrée du paquet
}

// TODO: define struct headers
struct headers {
    ethernet_t ethernet;
    packet_in_t cpu;  // Pour le clonage et envoi vers le contrôleur
}

// TODO: define struct metadata
// Structure des métadonnées utilisateur
struct metadata {
    @field_list(1)
    bit<9> ingress_port;  // Port d'entrée du paquet
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
        hdr.ethernet.dstAddr = packet.extract<bit<48>>();
        hdr.ethernet.srcAddr = packet.extract<bit<48>>();
        hdr.ethernet.etherType = packet.extract<bit<16>>();

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

    // TODO: copy forward and broadcast actions from previous exercise
    // Table de forwarding pour l'adresse MAC destination
    table dmac {
        key = {
            hdr.ethernet.dstAddr: exact;
        }
        actions = {
            forward;
            broadcast;
        }
        default_action = forward(port = 255);
    }

    // TODO: copy dmac and mcast_grp tables from previous exercise
    // Table pour l'adresse MAC source
    table smac {
        key = {
            hdr.ethernet.srcAddr: exact;
        }
        actions = {
            mac_learn;
        }
        default_action = mac_learn;
    }

    // TODO: add mac_learn action, saving ingress_port and cloning packet
    // Action pour l'apprentissage des adresses MAC
    action mac_learn(bit<9> ingress_port) {
        meta.ingress_port = ingress_port;
        // Clonage du paquet vers le pipeline egress (session 100)
        clone_preserving_field_list(100);
    }

    // TODO: add smac table to learn from source MAC address
    // TODO: apply smac table
    apply(smac);

    // TODO (copy from previous exercise)
    // -> apply mcast_grp table if no hit on dmac table
    apply(dmac);
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
*************   C H E C K S U M    C O M P U T A T I O N   **************
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
