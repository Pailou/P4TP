/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

struct metadata {
    /* empty */
}

struct headers {
    /* empty for the repeater */
}

/*************************************************************************
************************* P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
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

    /* TODO v2: solution with a table */
    /* Define:
     *  - an action that modifies smeta.egress_spec
     *  - a table that matches smeta.ingress_port and calls the previous action
     */

    // Action qui positionne le port de sortie (egress_spec)
    action set_egress(bit<9> port) {
        smeta.egress_spec = port;
    }

    // Table avec un match exact sur ingress_port
    table port_fwd_table {
        key = {
            smeta.ingress_port : exact;
        }
        actions = {
            set_egress;
            NoAction;
        }
        size = 256;
        default_action = NoAction;
    }

    apply {
        /* TODO v1: solution without a table */
        /* Write the code directly here */
        if (smeta.ingress_port == 1) {
            smeta.egress_spec = 2; // Ex : rediriger les paquets du port 1 vers le port 2
        } else if (smeta.ingress_port == 2) {
            smeta.egress_spec = 1; // Ex : rediriger les paquets du port 2 vers le port 1
        } else {
            smeta.egress_spec = smeta.ingress_port; // Bouclage sur le même port pour d'autres cas
        }

        /* TODO v2: solution with a table */
        /* Apply the table you use */
        port_fwd_table.apply();
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { }
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
        /* Deparser not needed for the repeater */
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
