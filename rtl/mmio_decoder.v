`timescale 1ns / 1ps
//=============================================================================
// Address Decoder and MMIO Router
//-----------------------------------------------------------------------------
// Memory Map:
//   0x0000_0000 - 0x0000_3FFF  : Instruction/Data Memory (16 KB)
//   0x1000_0000 - 0x1000_00FF  : Dummy Accelerator MMIO
//   0x2000_0000 - 0x2000_000F  : GPIO / LEDs (optional)
//=============================================================================

module mmio_decoder (
    input  wire        clk,
    input  wire        resetn,

    // CPU memory interface (from PicoRV32)
    input  wire        cpu_mem_valid,
    input  wire        cpu_mem_instr,
    input  wire [31:0] cpu_mem_addr,
    input  wire [31:0] cpu_mem_wdata,
    input  wire [ 3:0] cpu_mem_wstrb,
    output reg  [31:0] cpu_mem_rdata,
    output reg         cpu_mem_ready,

    // Memory interface
    output wire        mem_valid,
    output wire [31:0] mem_addr,
    output wire [31:0] mem_wdata,
    output wire [ 3:0] mem_wstrb,
    input  wire [31:0] mem_rdata,
    input  wire        mem_ready,

    // Accelerator MMIO interface
    output wire        accel_mmio_valid,
    output wire [31:0] accel_mmio_addr,
    output wire [31:0] accel_mmio_wdata,
    output wire [ 3:0] accel_mmio_wstrb,
    input  wire [31:0] accel_mmio_rdata,
    input  wire        accel_mmio_ready,

    // GPIO interface (optional)
    output wire        gpio_valid,
    output wire [31:0] gpio_addr,
    output wire [31:0] gpio_wdata,
    output wire [ 3:0] gpio_wstrb,
    input  wire [31:0] gpio_rdata,
    input  wire        gpio_ready
);

    //=========================================================================
    // Address decode
    //=========================================================================
    localparam ADDR_MEM_BASE   = 32'h0000_0000;
    localparam ADDR_MEM_MASK   = 32'hFFFF_C000;  // 16 KB

    localparam ADDR_ACCEL_BASE = 32'h1000_0000;
    localparam ADDR_ACCEL_MASK = 32'hFFFF_FF00;  // 256 bytes

    localparam ADDR_GPIO_BASE  = 32'h2000_0000;
    localparam ADDR_GPIO_MASK  = 32'hFFFF_FFF0;  // 16 bytes

    // Select signals
    wire sel_mem   = (cpu_mem_addr & ADDR_MEM_MASK)   == ADDR_MEM_BASE;
    wire sel_accel = (cpu_mem_addr & ADDR_ACCEL_MASK)  == ADDR_ACCEL_BASE;
    wire sel_gpio  = (cpu_mem_addr & ADDR_GPIO_MASK)   == ADDR_GPIO_BASE;

    //=========================================================================
    // Route signals to peripherals
    //=========================================================================
    assign mem_valid        = cpu_mem_valid && sel_mem;
    assign mem_addr         = cpu_mem_addr;
    assign mem_wdata        = cpu_mem_wdata;
    assign mem_wstrb        = cpu_mem_wstrb;

    assign accel_mmio_valid = cpu_mem_valid && sel_accel;
    assign accel_mmio_addr  = cpu_mem_addr - ADDR_ACCEL_BASE;
    assign accel_mmio_wdata = cpu_mem_wdata;
    assign accel_mmio_wstrb = cpu_mem_wstrb;

    assign gpio_valid       = cpu_mem_valid && sel_gpio;
    assign gpio_addr        = cpu_mem_addr - ADDR_GPIO_BASE;
    assign gpio_wdata       = cpu_mem_wdata;
    assign gpio_wstrb       = cpu_mem_wstrb;

    //=========================================================================
    // Mux return data and ready signals
    //=========================================================================
    always @(*) begin
        cpu_mem_rdata = 32'd0;
        cpu_mem_ready = 1'b0;

        if (sel_mem) begin
            cpu_mem_rdata = mem_rdata;
            cpu_mem_ready = mem_ready;
        end
        else if (sel_accel) begin
            cpu_mem_rdata = accel_mmio_rdata;
            cpu_mem_ready = accel_mmio_ready;
        end
        else if (sel_gpio) begin
            cpu_mem_rdata = gpio_rdata;
            cpu_mem_ready = gpio_ready;
        end
        else begin
            // Unmapped address: return ready to avoid hang
            cpu_mem_ready = cpu_mem_valid;
            cpu_mem_rdata = 32'hDEAD_BEEF;
        end
    end

endmodule

