`timescale 1ns / 1ps
//=============================================================================
// SoC Top-Level Integration
//-----------------------------------------------------------------------------
// Integrates:
//   - PicoRV32 RISC-V CPU
//   - SRAM (16 KB instruction/data memory)
//   - Address decoder / MMIO router
//   - Dummy MAC Accelerator (MMIO-mapped)
//
// Memory Map:
//   0x0000_0000 - 0x0000_3FFF  : SRAM (16 KB)
//   0x1000_0000 - 0x1000_00FF  : Accelerator MMIO
//   0x2000_0000 - 0x2000_000F  : GPIO (active-low active)
//=============================================================================

module soc_top #(
    parameter MEM_SIZE_BYTES = 16384,   // 16 KB
    parameter FIRMWARE_FILE  = ""       // Optional: hex file to preload
) (
    input  wire        clk,
    input  wire        resetn,

    // External GPIO
    output reg  [31:0] gpio_out,
    output wire        trap,

    // Accelerator IRQ output (directly accessible for monitoring)
    output wire        accel_irq_done
);

    //=========================================================================
    // CPU signals
    //=========================================================================
    wire        cpu_mem_valid;
    wire        cpu_mem_instr;
    wire        cpu_mem_ready;
    wire [31:0] cpu_mem_addr;
    wire [31:0] cpu_mem_wdata;
    wire [ 3:0] cpu_mem_wstrb;
    wire [31:0] cpu_mem_rdata;

    // Unused PCPI signals (tied off)
    wire        pcpi_valid;
    wire [31:0] pcpi_insn;
    wire [31:0] pcpi_rs1;
    wire [31:0] pcpi_rs2;

    // IRQ
    wire [31:0] irq;
    wire [31:0] eoi;

    //=========================================================================
    // Address decoder signals
    //=========================================================================
    wire        mem_valid, accel_valid, gpio_valid;
    wire [31:0] mem_addr,  accel_addr,  gpio_addr;
    wire [31:0] mem_wdata, accel_wdata, gpio_wdata;
    wire [ 3:0] mem_wstrb, accel_wstrb, gpio_wstrb;
    wire [31:0] mem_rdata, accel_rdata, gpio_rdata;
    wire        mem_ready, accel_ready, gpio_ready;

    //=========================================================================
    // PicoRV32 CPU Instance
    //=========================================================================
    picorv32 #(
        .ENABLE_COUNTERS     (1),
        .ENABLE_COUNTERS64   (0),
        .ENABLE_REGS_16_31   (1),
        .ENABLE_REGS_DUALPORT(1),
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
        .ENABLE_IRQ_QREGS    (0),
        .ENABLE_IRQ_TIMER    (0),
        .ENABLE_TRACE        (0),
        .REGS_INIT_ZERO      (1),
        .PROGADDR_RESET      (32'h0000_0000),
        .PROGADDR_IRQ        (32'h0000_0010),
        .STACKADDR           (32'h0000_3FFC)   // Top of 16KB SRAM
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

        // Look-ahead (unused)
        .mem_la_read  (),
        .mem_la_write (),
        .mem_la_addr  (),
        .mem_la_wdata (),
        .mem_la_wstrb (),

        // PCPI (disabled)
        .pcpi_valid(pcpi_valid),
        .pcpi_insn (pcpi_insn),
        .pcpi_rs1  (pcpi_rs1),
        .pcpi_rs2  (pcpi_rs2),
        .pcpi_wr   (1'b0),
        .pcpi_rd   (32'd0),
        .pcpi_wait (1'b0),
        .pcpi_ready(1'b0),

        // IRQ
        .irq (irq),
        .eoi (eoi),

        // Trace (unused)
        .trace_valid (),
        .trace_data  ()
    );

    //=========================================================================
    // Address Decoder
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

        .mem_valid      (mem_valid),
        .mem_addr       (mem_addr),
        .mem_wdata      (mem_wdata),
        .mem_wstrb      (mem_wstrb),
        .mem_rdata      (mem_rdata),
        .mem_ready      (mem_ready),

        .accel_mmio_valid (accel_valid),
        .accel_mmio_addr  (accel_addr),
        .accel_mmio_wdata (accel_wdata),
        .accel_mmio_wstrb (accel_wstrb),
        .accel_mmio_rdata (accel_rdata),
        .accel_mmio_ready (accel_ready),

        .gpio_valid     (gpio_valid),
        .gpio_addr      (gpio_addr),
        .gpio_wdata     (gpio_wdata),
        .gpio_wstrb     (gpio_wstrb),
        .gpio_rdata     (gpio_rdata),
        .gpio_ready     (gpio_ready)
    );

    //=========================================================================
    // SRAM Memory (16 KB)
    //=========================================================================
    localparam MEM_WORDS = MEM_SIZE_BYTES / 4;

    reg [31:0] memory [0:MEM_WORDS-1];
    reg        mem_ready_reg;

    // Initialize memory
    initial begin
        // Zero-initialize
        integer i;
        for (i = 0; i < MEM_WORDS; i = i + 1)
            memory[i] = 32'h0;
        // Load firmware if specified
        if (FIRMWARE_FILE != "")
            $readmemh(FIRMWARE_FILE, memory);
    end

    // Single-cycle SRAM read/write
    always @(posedge clk) begin
        mem_ready_reg <= 1'b0;
        if (mem_valid && !mem_ready_reg) begin
            mem_ready_reg <= 1'b1;
            if (mem_wstrb[0]) memory[mem_addr[31:2]][7:0]   <= mem_wdata[7:0];
            if (mem_wstrb[1]) memory[mem_addr[31:2]][15:8]  <= mem_wdata[15:8];
            if (mem_wstrb[2]) memory[mem_addr[31:2]][23:16] <= mem_wdata[23:16];
            if (mem_wstrb[3]) memory[mem_addr[31:2]][31:24] <= mem_wdata[31:24];
        end
    end

    assign mem_rdata = memory[mem_addr[31:2]];
    assign mem_ready = mem_ready_reg;

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

    // Accelerator IRQ (disabled for MMIO polling)
    assign irq = 32'd0;

    //=========================================================================
    // GPIO Peripheral (simple output register)
    //=========================================================================
    reg gpio_ready_reg;

    always @(posedge clk) begin
        gpio_ready_reg <= 1'b0;
        if (!resetn) begin
            gpio_out <= 32'd0;
        end else if (gpio_valid && !gpio_ready_reg) begin
            gpio_ready_reg <= 1'b1;
            if (gpio_wstrb != 4'b0000)
                gpio_out <= gpio_wdata;
        end
    end

    assign gpio_rdata = gpio_out;
    assign gpio_ready = gpio_ready_reg;

endmodule

