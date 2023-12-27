`default_nettype none
module axi_arp_rx #(
  parameter DEBUG = 1,
  parameter MAC_MSB = 24'h010203,
  parameter MAC_LSB = 24'h040506,
  parameter IP_MSB = 16'hc0a8,
  parameter IP_LSB = 16'h0602)
(
  input wire         clk,
  input wire         aresetn,

  input wire         s_axis_tvalid,
  input wire [7:0]   s_axis_tdata,
  input wire         s_axis_tlast,
  output wire        s_axis_tready,

  output wire        arp_valid,
  input wire         arp_ready,
  output wire [15:0] arp_opcode,
  output wire [47:0] arp_src_mac,
  output wire [31:0] arp_src_ip,
  output wire [47:0] arp_dst_mac,
  output wire [31:0] arp_dst_ip
);

  localparam string TAG = "axi_arp_rx";

  typedef enum bit [1:0] {
    S_PARSE,
    S_SKIP,
    S_PROCESS
  } state_t;

  typedef struct packed {
    state_t   state;
    bit [7:0] index;
    bit malformed;
    bit [15:0] opcode;
    bit [47:0] src_mac;
    bit [31:0] src_ip;
    bit [47:0] dst_mac;
    bit [31:0] dst_ip;
    bit        valid;
    bit        pvalid;
  } reg_t;

  localparam reg_t RES_reg = '{
    state     : S_PARSE,
    index     : 'h0,
    malformed : 'h0,
    opcode    : 'h0,
    src_mac   : 'h0,
    src_ip    : 'h0,
    dst_mac   : 'h0,
    dst_ip    : 'h0,
    valid     : 'h0,
    pvalid    : 'h0
  };


  reg_t r;
  reg_t rin;

  always_comb begin
    reg_t v;
    v        = r;

    v.pvalid = r.valid;

    case (r.state)
        S_PARSE : begin
          if (s_axis_tvalid) begin
            case (r.index)
              'h000: if (s_axis_tdata != ARP_HW_TYPE[15-:8]) v.state = S_SKIP;
              'h001: if (s_axis_tdata != ARP_HW_TYPE[ 7-:8]) v.state = S_SKIP;
              'h002: if (s_axis_tdata != ARP_PROTO_TYPE[15-:8]) v.state = S_SKIP;
              'h003: if (s_axis_tdata != ARP_PROTO_TYPE[ 7-:8]) v.state = S_SKIP;
              'h004: if (s_axis_tdata != ARP_HW_SIZE) v.state = S_SKIP;
              'h005: if (s_axis_tdata != ARP_PROTO_SIZE) v.state = S_SKIP;
              'h006: v.opcode[15-:8]  = s_axis_tdata;
              'h007: v.opcode[ 7-:8]  = s_axis_tdata;
              'h008: v.src_mac[47-:8] = s_axis_tdata;
              'h009: v.src_mac[39-:8] = s_axis_tdata;
              'h00a: v.src_mac[31-:8] = s_axis_tdata;
              'h00b: v.src_mac[23-:8] = s_axis_tdata;
              'h00c: v.src_mac[15-:8] = s_axis_tdata;
              'h00d: v.src_mac[ 7-:8] = s_axis_tdata;
              'h00e: v.src_ip[31-:8]  = s_axis_tdata;
              'h00f: v.src_ip[23-:8]  = s_axis_tdata;
              'h010: v.src_ip[15-:8]  = s_axis_tdata;
              'h011: v.src_ip[ 7-:8]  = s_axis_tdata;
              'h012: v.dst_mac[47-:8] = s_axis_tdata;
              'h013: v.dst_mac[39-:8] = s_axis_tdata;
              'h014: v.dst_mac[31-:8] = s_axis_tdata;
              'h015: v.dst_mac[23-:8] = s_axis_tdata;
              'h016: v.dst_mac[15-:8] = s_axis_tdata;
              'h017: v.dst_mac[ 7-:8] = s_axis_tdata;
              'h018: v.dst_ip[31-:8]  = s_axis_tdata;
              'h019: v.dst_ip[23-:8]  = s_axis_tdata;
              'h01a: v.dst_ip[15-:8]  = s_axis_tdata;
              'h01b: begin
                v.dst_ip[ 7-:8] = s_axis_tdata;
                if (s_axis_tlast) begin
                  v.valid = 1'b1;
                  v.state = S_PROCESS;
                end else begin
                  v.state = S_SKIP;
                end
              end
            endcase // case (r.index)
            v.index = r.index + 1;
          end // if (s_axis_tvalid)
        end // case: S_PARSE
      S_SKIP: begin
        if (s_axis_tvalid && s_axis_tlast) begin
          v.state = S_PARSE;
          v.valid = 1'b0;
          v.index = 'h0;
        end
      end
      S_PROCESS: begin
        if (arp_ready) begin
          v.index = 'h0;
          v.valid = 1'b0;
          v.state = S_PARSE;
        end
      end
      default:;
    endcase // case (r.state)


    if (~aresetn) begin
      v = RES_reg;
    end
    rin = v;
  end

  always_ff @(posedge clk) begin
    r <= rin;
    if (DEBUG) begin
      if (r.valid && ~r.pvalid) begin
        $display("%t : %-12s : OP %02h, SMAC %012h, SADDR %08h, DMAC %012h, DADDR %08h",
                 $time(), TAG,
                 r.opcode,
                 r.src_mac, r.src_ip,
                 r.dst_mac, r.dst_ip);
      end
    end
  end

  assign s_axis_tready = (r.state == S_PARSE) || (r.state == S_SKIP);

  assign arp_valid   = r.valid;
  assign arp_opcode  = r.opcode;
  assign arp_src_mac = r.src_mac;
  assign arp_src_ip  = r.src_ip;
  assign arp_dst_mac = r.dst_mac;
  assign arp_dst_ip  = r.dst_ip;

endmodule : axi_arp_rx
`default_nettype wire
