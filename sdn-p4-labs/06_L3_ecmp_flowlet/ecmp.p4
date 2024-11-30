/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

#define REGISTER_SIZE 4096
#define FLOWLET_TIMEOUT 48w200000
const bit<16> TYPE_IPV4 = 0x800;


typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<6>    dscp;
    bit<2>    ecn;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

header tcp_t{
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<4>  res;
    bit<1>  cwr;
    bit<1>  ece;
    bit<1>  urg;
    bit<1>  ack;
    bit<1>  psh;
    bit<1>  rst;
    bit<1>  syn;
    bit<1>  fin;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

struct headers {
    ethernet_t   ethernet;
    ipv4_t       ipv4;
    tcp_t        tcp;
}

struct metadata {
    // TODO: define the metadata needed to store the ecmp_hash
	bit<16> result;

	bit<16> flowlet_register_index;
	bit<16> flowlet_id;
    	bit<48> flowlet_time_stamp;
}

/*************************************************************************
************************* P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t smeta) {

    // TODO: parse ethernet, ipv4 and tcp
    state start {
	packet.extract(hdr.ethernet);
	transition select(hdr.ethernet.etherType) {
		TYPE_IPV4: parse_ipv4;
		default: accept;
	   }
	}
	state parse_ipv4 {
		packet.extract(hdr.ipv4);
		transition select(hdr.ipv4.protocol) { 
			6: parse_tcp;
			default: accept;
			}
		}

	state parse_tcp {
		packet.extract(hdr.tcp);
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

	register<bit<16>>(REGISTER_SIZE) flowlet_id;
	register<bit<48>>(REGISTER_SIZE) flowlet_time_stamp;

	direct_counter(CounterType.packets_and_bytes) dst_prefix_counter;


	 action read_flowlet_registers(){
		hash(meta.flowlet_register_index, HashAlgorithm.crc16,
            	(bit<16>)0,
            	{ hdr.ipv4.srcAddr, hdr.ipv4.dstAddr, hdr.tcp.srcPort, hdr.tcp.dstPort,hdr.ipv4.protocol},
            	(bit<14>)4096);

		flowlet_time_stamp.read(meta.flowlet_time_stamp, (bit<32>)meta.flowlet_register_index);
		flowlet_id.read(meta.flowlet_id, (bit<32>)meta.flowlet_register_index);

		flowlet_time_stamp.write((bit<32>)meta.flowlet_register_index, smeta.ingress_global_timestamp);

	}

	action update_flowlet_id() {
	        bit<32> random_t;
	        random(random_t, (bit<32>)0, (bit<32>)65000);
	        meta.flowlet_id = (bit<16>)random_t;
	        flowlet_id.write((bit<32>)meta.flowlet_register_index, (bit<16>)meta.flowlet_id);
	}

	
    // TODO: define the set_ecmp action (with the hash function)
	action set_ecmp(bit<8> nbr_sauts){
		bit<1> base = 0;
		HashAlgorithm algo = HashAlgorithm.crc16;
	        //meta.result = 0;
	        hash(meta.result, algo, base, {hdr.ipv4.srcAddr, hdr.ipv4.dstAddr, hdr.tcp.srcPort, hdr.tcp.dstPort,meta.flowlet_id}, nbr_sauts);
	}

    // TODO: define the set_nhop action
	action set_nhop(macAddr_t dstAddr, egressSpec_t port) {
		hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
		hdr.ethernet.dstAddr = dstAddr;
		hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
		smeta.egress_spec = port;
	}

    // TODO: define the IP forwarding table (ipv4_lpm)
	table ipv4_lpm {
		key = {
			hdr.ipv4.dstAddr : lpm;
		}
		actions = {
			set_nhop;
			set_ecmp;
			NoAction;
		}
		counters = dst_prefix_counter;
		default_action = NoAction();
		
	}

    // TODO: define the ecmp table (ecmp_to_nhop)
    // this table is only called when multiple hops are available
	 table ecmp_to_nhop {
	        key = {
	            meta.result: exact;
	        }
	        actions = {
	            set_nhop;
	            NoAction;
	        }
	        default_action = NoAction();
    	}

    apply {
        // TODO: apply
	if (hdr.ipv4.isValid()) {
	    read_flowlet_registers();
	    if ((smeta.ingress_global_timestamp - meta.flowlet_time_stamp) >FLOWLET_TIMEOUT){
		update_flowlet_id();
	    }
            switch (ipv4_lpm.apply().action_run) {
                set_ecmp: {
                    ecmp_to_nhop.apply();
                    }
    		  }
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
        /* empty */
    }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   ***************
*************************************************************************/

control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
    apply {
        update_checksum(
	        hdr.ipv4.isValid(),
            { hdr.ipv4.version,
	          hdr.ipv4.ihl,
              hdr.ipv4.dscp,
              hdr.ipv4.ecn,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr
            },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

/*************************************************************************
***********************  D E P A R S E R  ********************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        // TODO: deparse ethernet, ipv4 and tcp headers
	packet.emit(hdr.ethernet);
	packet.emit(hdr.ipv4);
	packet.emit(hdr.tcp);
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
