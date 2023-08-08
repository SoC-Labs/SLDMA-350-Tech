//-----------------------------------------------------------------------------
// DMA350 wrapper - Contains DMA Controllers with AHB interface
// A joint work commissioned on behalf of SoC Labs, under Arm Academic Access l
//
// Contributors
//
// Daniel Newbrook (d.newbrook@soton.ac.uk)
//
// Copyright 2021-3, SoC Labs (www.soclabs.org)
//-----------------------------------------------------------------------------


module sldma350_ahb #(
    parameter    SYS_ADDR_W  = 32,
    parameter    SYS_DATA_W  = 32,
    parameter    CFG_ADDR_W  = 12,  // Configuration Port Address Width
    parameter    CHANNEL_NUM = 2    // Number of DMA Channels

    )(
    // AHB Clocks and Resets 
    input wire                     HCLK,
    input wire                     HRESETn,

    // AHB Lite Port
    output wire   [SYS_ADDR_W-1:0] HADDR,       // Address bus
    output wire              [1:0] HTRANS,      // Transfer type
    output wire                    HWRITE,      // Transfer direction
    output wire              [2:0] HSIZE,       // Transfer size
    output wire              [2:0] HBURST,      // Burst type
    output wire              [3:0] HPROT,       // Protection control
    output wire   [SYS_DATA_W-1:0] HWDATA,      // Write data
    output wire                    HMASTLOCK,   // Locked Sequence
    input  wire   [SYS_DATA_W-1:0] HRDATA,      // Read data bus
    input  wire                    HREADY,      // HREADY feedback
    input  wire                    HRESP,       // Transfer response
    
    // APB Configurtation Port
    input  wire                    PCLKEN,      // APB clock enable
    input  wire                    PSEL,        // APB peripheral select
    input  wire                    PEN,         // APB transfer enable
    input  wire                    PWRITE,      // APB transfer direction
    input  wire   [CFG_ADDR_W-1:0] PADDR,       // APB address
    input  wire   [SYS_DATA_W-1:0] PWDATA,      // APB write data
    output wire   [SYS_DATA_W-1:0] PRDATA,      // APB read data
    
    // DMA Request and Status Port
    input  wire  [CHANNEL_NUM-1:0] DMA_REQ,     // DMA transfer request
    output wire  [CHANNEL_NUM-1:0] DMA_DONE,    // DMA transfer done
    output wire                    DMA_ERR      // DMA slave response not OK
);


wire                    SYS_HRESETn,
wire                    DMAC_PCLKen,
wire                    DMAC_ACLKen,

// Q Channel Signals
wire                    DMAC_CLK_QREQN,
wire                    DMAC_CLK_QACCEPTN,
wire                    DMAC_CLK_QDENY,
wire                    DMAC_CLK_QACTIVE,

// P Channel Signals
wire                     DMAC_PREQ,
wire  [3:0]              DMAC_PSTATE,
wire                     DMAC_PACCEPT,
wire                     DMAC_PDENY,
wire [9:0]               DMAC_PACTIVE,
wire                     DMAC_PWAKEUP,
wire                     DMAC_PDEBUG,
wire                     DMAC_PSEL,
wire                     DMAC_PENABLE,
wire  [2:0]              DMAC_PPROT,
wire                     DMAC_PWRITE,
wire  [12:0]             DMAC_PADDR,
wire  [31:0]             DMAC_PWDATA,
wire  [3:0]              DMAC_PSTRB,
wire                     DMAC_PREADY,
wire                     DMAC_PSLVERR,
wire [31:0]              DMAC_PRDATA,
//  DMAC AXI Port
wire                     DMAC_AWAKEUP,
wire                     DMAC_AWVALID,
wire [SYS_ADDR_W-1:0]    DMAC_AWADDR,
wire [1:0]               DMAC_AWBURST,
wire [7:0]               DMAC_AWLEN,
wire [2:0]               DMAC_AWSIZE,
wire [3:0]               DMAC_AWQOS,
wire [2:0]               DMAC_AWPROT,
wire                     DMAC_AWREADY,
wire [3:0]               DMAC_AWCACHE,
wire [3:0]               DMAC_AWINNER,
wire [1:0]               DMAC_AWDOMAIN,

wire                     DMAC_ARVALID,
wire [SYS_ADDR_W-1:0]    DMAC_ARADDR,
wire [1:0]               DMAC_ARBURST,
wire [7:0]               DMAC_ARLEN,
wire [2:0]               DMAC_ARSIZE,
wire [3:0]               DMAC_ARQOS,
wire [2:0]               DMAC_ARPROT,
wire                     DMAC_ARREADY,
wire [3:0]               DMAC_ARCACHE,
wire [3:0]               DMAC_ARINNER,
wire [1:0]               DMAC_ARDOMAIN,
wire                     DMAC_ARCMDLINK,

wire                     DMAC_WVALID,
wire                     DMAC_WLAST,
wire [16-1:0]            DMAC_WSTRB,
wire [SYS_DATA_W-1:0]    DMAC_WDATA,
wire                     DMAC_WREADY,
wire                     DMAC_RVALID,
wire                     DMAC_RLAST,
wire  [SYS_DATA_W-1:0]   DMAC_RDATA,
wire  [2-1:0]            DMAC_RPOISON,
wire  [1:0]              DMAC_RRESP,
wire                     DMAC_RREADY,

wire                     DMAC_BVALID,
wire  [1:0]              DMAC_BRESP,
wire                     DMAC_BREADY,

// Trigger 0 in
wire                     DMAC_TRIG_IN_0_REQ,
wire  [1:0]              DMAC_TRIG_IN_0_REQ_TYPE,
wire                     DMAC_TRIG_IN_0_ACK,
wire [1:0]               DMAC_TRIG_IN_0_ACK_TYPE,
wire                     DMAC_TRIG_IN_1_REQ,
wire  [1:0]              DMAC_TRIG_IN_1_REQ_TYPE,
wire                     DMAC_TRIG_IN_1_ACK,
wire [1:0]               DMAC_TRIG_IN_1_ACK_TYPE,
wire                     DMAC_TRIG_OUT_0_REQ,
wire                     DMAC_TRIG_OUT_0_ACK,
wire                     DMAC_TRIG_OUT_1_REQ,
wire                     DMAC_TRIG_OUT_1_ACK,
wire [2-1:0]             DMAC_IRQ_CHANNEL,
wire                     DMAC_IRQ_COMB_NONSEC,

//  DMAC Channel 0 AXI stream out
wire                     DMAC_STR_OUT_0_TVALID,
wire                     DMAC_STR_OUT_0_TREADY,
wire [SYS_DATA_W-1:0]    DMAC_STR_OUT_0_TDATA,
wire [16-1:0]            DMAC_STR_OUT_0_TSTRB,
wire                     DMAC_STR_OUT_0_TLAST,

//  DMAC Channel 0 AXI Stream in
wire                     DMAC_STR_IN_0_TVALID,
wire                     DMAC_STR_IN_0_TREADY,
wire [SYS_DATA_W-1:0]    DMAC_STR_IN_0_TDATA,
wire [16-1:0]            DMAC_STR_IN_0_TSTRB,
wire                     DMAC_STR_IN_0_TLAST,
wire                     DMAC_STR_IN_0_FLUSH,

//  DMAC Channel 1 AXI Stream out
wire                     DMAC_STR_OUT_1_TVALID,
wire                     DMAC_STR_OUT_1_TREADY,
wire [SYS_DATA_W-1:0]    DMAC_STR_OUT_1_TDATA,
wire [16-1:0]            DMAC_STR_OUT_1_TSTRB,
wire                     DMAC_STR_OUT_1_TLAST,

//  DMAC Channel 1 AXI Stream out
wire                     DMAC_STR_IN_1_TVALID,
wire                     DMAC_STR_IN_1_TREADY,
wire [SYS_DATA_W-1:0]    DMAC_STR_IN_1_TDATA,
wire [16-1:0]            DMAC_STR_IN_1_TSTRB,
wire                     DMAC_STR_IN_1_TLAST,
wire                     DMAC_STR_IN_1_FLUSH,
wire                     DMAC_ALLCH_STOP_REQ_NONSEC,
wire                     DMAC_ALLCH_STOP_ACK_NONSEC,
wire                     DMAC_ALLCH_PAUSE_REQ_NONSEC,
wire                     DMAC_ALLCH_PAUSE_ACK_NONSEC,
wire [2-1:0]             DMAC_CH_ENABLED,
wire [2-1:0]             DMAC_CH_ERR,
wire [2-1:0]             DMAC_CH_STOPPED,
wire [2-1:0]             DMAC_CH_PAUSED,
wire [2-1:0]             DMAC_CH_PRIV,

wire                     DMAC_HALT_REQ,
wire                     DMAC_RESTART_REQ,
wire                     DMAC_HALTED,
wire                     DMAC_BOOT_EN,
wire  [32-1:2]           DMAC_BOOT_ADDR,
wire  [ 7:0]             DMAC_BOOT_MEMATTR,
wire  [ 1:0]             DMAC_BOOT_SHAREATTR

// -------------------------------
// DMA Controller Instantiation
// -------------------------------
ada_top_sldma350 u_dmac_0(
    // Clock and Reset signals
    .clk(HCLK),
    .resetn(HRESETn),
    .aclken_m0(DMAC_ACLKen),
    .pclken(PCLKEN),
    // Q Channel signals
    .clk_qreqn(DMAC_CLK_QREQN),
    .clk_qacceptn(DMAC_CLK_QACCEPTN),
    .clk_qdeny(DMAC_CLK_QDENY),
    .clk_qactive(DMAC_CLK_QACTIVE),
    // P Channel Signals
    .preq(DMAC_PREQ),
    .pstate(DMAC_PSTATE),
    .paccept(DMAC_PACCEPT),
    .pdeny(DMAC_PDENY),
    .pactive(DMAC_PACTIVE),

    .pwakeup(DMAC_PWAKEUP),
    .pdebug(DMAC_PDEBUG),
    .psel(PSEL),
    .penable(PEN),
    .pprot(DMAC_PPROT),
    .pwrite(PWRITE),
    .paddr(PADDR),
    .pwdata(PWDATA),
    .pstrb(DMAC_PSTRB),
    .pready(DMAC_PREADY),
    .pslverr(DMAC_PSLVERR),
    .prdata(PRDATA),
    // AXI Write Channel Signals
    .awakeup_m0(DMAC_AWAKEUP),
    .awvalid_m0(DMAC_AWVALID),
    .awaddr_m0(DMAC_AWADDR),
    .awburst_m0(DMAC_AWBURST),
    .awid_m0(),
    .awlen_m0(DMAC_AWLEN),
    .awsize_m0(DMAC_AWSIZE),
    .awqos_m0(DMAC_AWQOS),
    .awprot_m0(DMAC_AWPROT),
    .awready_m0(DMAC_AWREADY),
    .awcache_m0(DMAC_AWCACHE),
    .awinner_m0(DMAC_AWINNER),
    .awdomain_m0(DMAC_AWDOMAIN),
    // AXI Read Channel Signals
    .arvalid_m0(DMAC_ARVALID),
    .araddr_m0(DMAC_ARADDR),
    .arburst_m0(DMAC_ARBURST),
    .arid_m0(),
    .arlen_m0(DMAC_ARLEN),
    .arsize_m0(DMAC_ARSIZE),
    .arqos_m0(DMAC_ARQOS),
    .arprot_m0(DMAC_ARPROT),
    .arready_m0(DMAC_ARREADY),
    .arcache_m0(DMAC_ARCACHE),
    .arinner_m0(DMAC_ARINNER),
    .ardomain_m0(DMAC_ARDOMAIN),
    .arcmdlink_m0(DMAC_ARCMDLINK),
    // AXI Write Data Signals
    .wvalid_m0(DMAC_WVALID),
    .wlast_m0(DMAC_WLAST),
    .wstrb_m0(DMAC_WSTRB),
    .wdata_m0(DMAC_WDATA),
    .wready_m0(DMAC_WREADY),
    // AXI Read Data Signals
    .rvalid_m0(DMAC_RVALID),
    .rid_m0(),
    .rlast_m0(DMAC_RLAST),
    .rdata_m0(DMAC_RDATA),
    .rpoison_m0(DMAC_RPOISON),
    .rresp_m0(DMAC_RRESP),
    .rready_m0(DMAC_RREADY),
    // AXI Write response signals
    .bvalid_m0(DMAC_BVALID),
    .bid_m0(),
    .bresp_m0(DMAC_BRESP),
    .bready_m0(DMAC_BREADY),
    // Trigger 0 in
    .trig_in_0_req(DMAC_TRIG_IN_0_REQ),
    .trig_in_0_req_type(DMAC_TRIG_IN_0_REQ_TYPE),
    .trig_in_0_ack(DMAC_TRIG_IN_0_ACK),
    .trig_in_0_ack_type(DMAC_TRIG_IN_0_ACK_TYPE),
    // Trigger 1 in
    .trig_in_1_req(DMAC_TRIG_IN_1_REQ),
    .trig_in_1_req_type(DMAC_TRIG_IN_1_REQ_TYPE),
    .trig_in_1_ack(DMAC_TRIG_IN_1_ACK),
    .trig_in_1_ack_type(DMAC_TRIG_IN_1_ACK_TYPE),
    // Trigger 0 out
    .trig_out_0_req(DMAC_TRIG_OUT_0_REQ),
    .trig_out_0_ack(DMAC_TRIG_OUT_0_ACK),
    // Trigger 1 out
    .trig_out_1_req(DMAC_TRIG_OUT_1_REQ),
    .trig_out_1_ack(DMAC_TRIG_OUT_1_ACK),
    // Interrupt Signals
    .irq_channel(DMAC_IRQ_CHANNEL),
    .irq_comb_nonsec(DMAC_IRQ_COMB_NONSEC),
    // AXI Stream 0 out
    .str_out_0_tvalid(DMAC_STR_OUT_0_TVALID),
    .str_out_0_tready(DMAC_STR_OUT_0_TREADY),
    .str_out_0_tdata(DMAC_STR_OUT_0_TDATA),
    .str_out_0_tstrb(DMAC_STR_OUT_0_TSTRB),
    .str_out_0_tlast(DMAC_STR_OUT_0_TLAST),
    // AXI Stream 0 In
    .str_in_0_tvalid(DMAC_STR_IN_0_TVALID),
    .str_in_0_tready(DMAC_STR_IN_0_TREADY),
    .str_in_0_tdata(DMAC_STR_IN_0_TDATA),
    .str_in_0_tstrb(DMAC_STR_IN_0_TSTRB),
    .str_in_0_tlast(DMAC_STR_IN_0_TLAST),
    .str_in_0_flush(DMAC_STR_IN_0_FLUSH),
    // AXI Stream 1 out
    .str_out_1_tvalid(DMAC_STR_OUT_1_TVALID),
    .str_out_1_tready(DMAC_STR_OUT_1_TREADY),
    .str_out_1_tdata(DMAC_STR_OUT_1_TDATA),
    .str_out_1_tstrb(DMAC_STR_OUT_1_TSTRB),
    .str_out_1_tlast(DMAC_STR_OUT_1_TLAST),
    // AXI Stream 1 in
    .str_in_1_tvalid(DMAC_STR_IN_1_TVALID),
    .str_in_1_tready(DMAC_STR_IN_1_TREADY),
    .str_in_1_tdata(DMAC_STR_IN_1_TDATA),
    .str_in_1_tstrb(DMAC_STR_IN_1_TSTRB),
    .str_in_1_tlast(DMAC_STR_IN_1_TLAST),
    .str_in_1_flush(DMAC_STR_IN_1_FLUSH),

    .allch_stop_req_nonsec(DMAC_ALLCH_STOP_REQ_NONSEC),
    .allch_stop_ack_nonsec(DMAC_ALLCH_STOP_ACK_NONSEC),
    .allch_pause_req_nonsec(DMAC_ALLCH_PAUSE_REQ_NONSEC),
    .allch_pause_ack_nonsec(DMAC_ALLCH_PAUSE_ACK_NONSEC),
    .ch_enabled(DMAC_CH_ENABLED),
    .ch_err(DMAC_CH_ERR),
    .ch_stopped(DMAC_CH_STOPPED),
    .ch_paused(DMAC_CH_PAUSED),
    .ch_priv(DMAC_CH_PRIV),
    .halt_req(DMAC_HALT_REQ),
    .restart_req(DMAC_RESTART_REQ),
    .halted(DMAC_HALTED),
    .boot_en(DMAC_BOOT_EN),
    .boot_addr(DMAC_BOOT_ADDR),
    .boot_memattr(DMAC_BOOT_MEMATTR),
    .boot_shareattr(DMAC_BOOT_SHAREATTR)
);

xhb400 #(.DATA_WIDTH(SYS_DATA_W))
(
    //-----------------------------------------------------------------------------
    // Clock and Reset
    //-----------------------------------------------------------------------------

    .CLK(HCLK),
    .nSYSRESET(HRESETn),
    //-----------------------------------------------------------------------------
    // AXI Master Interface
    //-----------------------------------------------------------------------------

    // Write Address Channel signals
    .AWADDR(DMAC_AWADDR),
    .AWBURST(DMAC_AWBURST),
    .AWID(),
    .AWLEN(DMAC_AWLEN),
    .AWSIZE(DMAC_AWSIZE),
    .AWLOCK(),
    .AWPROT(DMAC_AWPROT),
    .AWCACHE(DMAC_AWCACHE),
    .AWUSER(),
    .AWSPARSE(),
    .AWVALID(DMAC_AWVALID),
    .AWREADY(DMAC_AWREADY),
  
// Read Address Channel signals  
    .ARADDR(DMAC_ARADDR),
    .ARBURST(DMAC_ARBURST),
    .ARID(),
    .ARLEN(DMAC_ARLEN),
    .ARSIZE(DMAC_ARSIZE),
    .ARLOCK(), 
    .ARPROT(DMAC_ARPROT),
    .ARCACHE(DMAC_ARCACHE),
    .ARUSER(),
    .ARVALID(DMAC_ARVALID),
    .ARREADY(DMAC_ARREADY),
  
// Write Data Channel signals   
    .WLAST(DMAC_WLAST),
    .WSTRB(DMAC_WSTRB),
    .WDATA(DMAC_WDATA),
    .WUSER(),
    .WVALID(DMAC_WVALID),
    .WREADY(DMAC_WREADY),
  
// Read Data Channel signals 
    .RREADY(DMAC_RREADY),   
    .RVALID(DMAC_RVALID),
    .RID(),
    .RLAST(DMAC_RLAST),
    .RDATA(DMAC_RDATA),
    .RUSER(),
    .RRESP(DMAC_RRESP),
  
// Write Response Channel signals 
    .BREADY(DMAC_BREADY),   
    .BVALID(DMAC_BVALID),
    .BID(),
    .BRESP(DMAC_BRESP),
  
  
//-----------------------------------------------------------------------------
// AHB-Lite Slave Interface
//-----------------------------------------------------------------------------

// AHB-Lite Master signals
    .HTRANS(HTRANS),
    .HBURST(HBURST),
    .HADDR(HADDR),
    .HWRITE(HWRITE),
    .HSIZE(HSIZE),
    .HWDATA(HWDATA),
    .HPROT(HPROT),
    .HMASTLOCK(HMASTLOCK),
  
// AHB-Lite Slave Response signals  
    .HREADY(HREADY),
    .HRDATA(HRDATA),
    .HRESP(HRESP),
  
// Non-standard Exclusive Access signals   
    .EXREQ,
    .EXRESP,

// Sideband AHB USER signals
    .HAUSER,
    .HWUSER,
    .HRUSER
);

endmodule
