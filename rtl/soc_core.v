`timescale 1ns / 1ps
//=============================================================================
// Synthesizable SoC Core (PicoRV32 + Dummy MAC Accelerator) for ASIC Flow
//-----------------------------------------------------------------------------
// Target: SkyWater 130nm PDK (sky130A) via OpenLane / OpenROAD
// This module contains the full digital core:
//   - PicoRV32 RISC-V CPU
//   - Dummy MAC Accelerator (Multi-cycle arithmetic pipeline)
//   - MMIO Address Decoder & Interconnect
//   - External Memory Bus (for off-chip / compiled SRAM macro interface)
//   - GPIO output pins
//=============================================================================

module soc_core (
    input  wire        clk,
    input  wire        resetn,

    // External Memory Interface (connected to external SRAM / flash)
    output wire        ext_mem_valid,
    output wire        ext_mem_instr,
    output wire [31:0] ext_mem_addr,
    output wire [31:0] ext_mem_wdata,
    output wire [ 3:0] ext_mem_wstrb,
    input  wire [31:0] ext_mem_rdata,
    input  wire        ext_mem_ready,

    // Status / Peripherals
    output wire [31:0] gpio_out,
    output wire        accel_irq_done,
    output wire        trap
);

    // CPU internal memory signals
    wire        cpu_mem_valid;
    wire        cpu_mem_instr;
    wire        cpu_mem_ready;
    wire [31:0] cpu_mem_addr;
    wire [31:0] cpu_mem_wdata;
    wire [ 3:0] cpu_mem_wstrb;
    wire [31:0] cpu_mem_rdata;

    // Accelerator MMIO bus
    wire        accel_valid;
    wire [31:0] accel_addr;
    wire [31:0] accel_wdata;
    wire [ 3:0] accel_wstrb;
    wire [31:0] accel_rdata;
    wire        accel_ready;

    // GPIO MMIO bus
    wire        gpio_valid;
    wire [31:0] gpio_addr;
    wire [31:0] gpio_wdata;
    wire [ 3:0] gpio_wstrb;
    wire [31:0] gpio_rdata;
    wire        gpio_ready;

    //=========================================================================
    // PicoRV32 CPU Core
    //=========================================================================
    picorv32 #(
        .ENABLE_COUNTERS     (1),
        .ENABLE_COUNTERS64   (0),
        .ENABLE_REGS_16_31   (1),
        .ENABLE_REGS_DUALPORT(0),   // Disabled: dual-port causes multi-driven Yosys check errors
        .LATCHED_MEM_RDATA   (0),
        .TWO_STAGE_SHIFT     (1),
        .BARREL_SHIFTER      (0),
        .TWO_CYCLE_COMPARE   (0),
        .TWO_CYCLE_ALU       (0),
        .COMPRESSED_ISA      (0),
        .CATCH_MISALIGN      (1),
        .CATCH_ILLINSN       (1),
        .ENABLE_PCPI         (0),
        .ENABLE_MUL          (0),
        .ENABLE_FAST_MUL     (0),
        .ENABLE_DIV          (0),
        .ENABLE_IRQ          (0),
        .ENABLE_TRACE        (0),
        .REGS_INIT_ZERO      (1),
        .PROGADDR_RESET      (32'h0000_0000),
        .STACKADDR           (32'h0000_3FFC)
    ) cpu (
        .clk       (clk),
        .resetn    (resetn),
        .trap      (trap),

        .mem_valid (cpu_mem_valid),
        .mem_instr (cpu_mem_instr),
        .mem_ready (cpu_mem_ready),
        .mem_addr  (cpu_mem_addr),
        .mem_wdata (cpu_mem_wdata),
        .mem_wstrb (cpu_mem_wstrb),
        .mem_rdata (cpu_mem_rdata),

        .mem_la_read  (),
        .mem_la_write (),
        .mem_la_addr  (),
        .mem_la_wdata (),
        .mem_la_wstrb (),

        .pcpi_valid(),
        .pcpi_insn (),
        .pcpi_rs1  (),
        .pcpi_rs2  (),
        .pcpi_wr   (1'b0),
        .pcpi_rd   (32'd0),
        .pcpi_wait (1'b0),
        .pcpi_ready(1'b0),

        .irq (32'd0),
        .eoi (),

        .trace_valid (),
        .trace_data  ()
    );

    //=========================================================================
    // MMIO Address Decoder & Router
    //=========================================================================
    mmio_decoder decoder (
        .clk            (clk),
        .resetn         (resetn),

        .cpu_mem_valid  (cpu_mem_valid),
        .cpu_mem_instr  (cpu_mem_instr),
        .cpu_mem_addr   (cpu_mem_addr),
        .cpu_mem_wdata  (cpu_mem_wdata),
        .cpu_mem_wstrb  (cpu_mem_wstrb),
        .cpu_mem_rdata  (cpu_mem_rdata),
        .cpu_mem_ready  (cpu_mem_ready),

        // Route to external memory interface
        .mem_valid      (ext_mem_valid),
        .mem_addr       (ext_mem_addr),
        .mem_wdata      (ext_mem_wdata),
        .mem_wstrb      (ext_mem_wstrb),
        .mem_rdata      (ext_mem_rdata),
        .mem_ready      (ext_mem_ready),

        // Route to Dummy Accelerator
        .accel_mmio_valid (accel_valid),
        .accel_mmio_addr  (accel_addr),
        .accel_mmio_wdata (accel_wdata),
        .accel_mmio_wstrb (accel_wstrb),
        .accel_mmio_rdata (accel_rdata),
        .accel_mmio_ready (accel_ready),

        // Route to GPIO
        .gpio_valid     (gpio_valid),
        .gpio_addr      (gpio_addr),
        .gpio_wdata     (gpio_wdata),
        .gpio_wstrb     (gpio_wstrb),
        .gpio_rdata     (gpio_rdata),
        .gpio_ready     (gpio_ready)
    );

    //=========================================================================
    // Dummy MAC Accelerator
    //=========================================================================
    dummy_accelerator accel (
        .clk          (clk),
        .resetn       (resetn),
        .mmio_valid   (accel_valid),
        .mmio_addr    (accel_addr),
        .mmio_wdata   (accel_wdata),
        .mmio_wstrb   (accel_wstrb),
        .mmio_rdata   (accel_rdata),
        .mmio_ready   (accel_ready),
        .irq_done     (accel_irq_done)
    );

    //=========================================================================
    // GPIO Register
    //=========================================================================
    reg [31:0] gpio_reg;
    reg        gpio_ready_reg;

    always @(posedge clk) begin
        if (!resetn) begin
            gpio_reg       <= 32'd0;
            gpio_ready_reg <= 1'b0;
        end else begin
            gpio_ready_reg <= 1'b0;
            if (gpio_valid && !gpio_ready_reg) begin
                gpio_ready_reg <= 1'b1;
                if (gpio_wstrb != 4'b0000)
                    gpio_reg <= gpio_wdata;
            end
        end
    end

    assign gpio_out   = gpio_reg;
    assign gpio_rdata = gpio_reg;
    assign gpio_ready = gpio_ready_reg;

endmodule

