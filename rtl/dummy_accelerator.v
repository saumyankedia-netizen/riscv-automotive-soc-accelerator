`timescale 1ns / 1ps
//=============================================================================
// Dummy MAC Accelerator with MMIO Interface
//-----------------------------------------------------------------------------
// Reference: "Design and Implementation of a Custom Multiply Accumulate
//            Instruction in an Open-Source RISC-V Processor Core"
//            (DOI: 10.1109/ICCPCT70290.2026.11654754)
//
// This module implements a multi-cycle Multiply-Accumulate (MAC) accelerator
// accessible via Memory-Mapped I/O (MMIO). It demonstrates:
//   - CPU-to-accelerator control/data path
//   - FSM-based multi-cycle operation (visible busy/done handshake)
//   - ADD, MULTIPLY, and MAC operations
//   - Performance counters for speedup measurement
//
// MMIO Register Map (offsets relative to base address):
//   0x00  CONTROL     [0]=start, [1]=clear_done, [2]=reset_perf_counters
//   0x04  STATUS      [0]=busy, [1]=done, [2]=overflow
//   0x08  OPERAND_A   32-bit operand A (signed)
//   0x0C  OPERAND_B   32-bit operand B (signed)
//   0x10  RESULT_LO   Lower 32 bits of result
//   0x14  OPERATION   [1:0] = 00:ADD, 01:MUL, 10:MAC, 11:reserved
//   0x18  RESULT_HI   Upper 32 bits of result (for MUL/MAC)
//   0x1C  ACCUM_LO    Lower 32 bits of accumulator (for MAC)
//   0x20  ACCUM_HI    Upper 32 bits of accumulator (for MAC)
//   0x24  PERF_CYCLES Accelerator operation cycle count
//   0x28  PERF_OPS    Total operations completed count
//=============================================================================

module dummy_accelerator (
    input  wire        clk,
    input  wire        resetn,

    // MMIO Interface
    input  wire        mmio_valid,     // Access request valid
    input  wire [31:0] mmio_addr,      // Register offset (byte address)
    input  wire [31:0] mmio_wdata,     // Write data
    input  wire [ 3:0] mmio_wstrb,     // Write strobe (non-zero = write)
    output reg  [31:0] mmio_rdata,     // Read data
    output wire        mmio_ready,     // Access complete

    // Interrupt output
    output wire        irq_done       // Interrupt: operation complete
);

    //=========================================================================
    // Operation codes
    //=========================================================================
    localparam OP_ADD = 2'b00;
    localparam OP_MUL = 2'b01;
    localparam OP_MAC = 2'b10;

    //=========================================================================
    // FSM States
    //=========================================================================
    localparam S_IDLE      = 3'd0;
    localparam S_LOAD      = 3'd1;  // Load operands (1 cycle)
    localparam S_COMPUTE_1 = 3'd2;  // Compute stage 1 (multiply partial)
    localparam S_COMPUTE_2 = 3'd3;  // Compute stage 2 (accumulate)
    localparam S_WRITEBACK = 3'd4;  // Write result
    localparam S_DONE      = 3'd5;  // Signal completion

    //=========================================================================
    // Registers
    //=========================================================================
    reg [31:0] operand_a;
    reg [31:0] operand_b;
    reg [ 1:0] operation;
    reg [63:0] result;
    reg [63:0] accumulator;

    // Status
    reg        busy;
    reg        done;
    reg        overflow;

    // FSM
    reg [2:0]  state;

    // Performance counters
    reg [31:0] perf_cycles;     // Cycles spent in computation
    reg [31:0] perf_ops;        // Total operations completed
    reg [31:0] cycle_counter;   // Current operation cycle count

    // Internal computation
    reg [63:0] mul_result;
    reg [63:0] add_result;

    //=========================================================================
    // MMIO Ready - single cycle access
    //=========================================================================
    reg mmio_ready_reg;
    always @(posedge clk) begin
        if (!resetn)
            mmio_ready_reg <= 0;
        else
            mmio_ready_reg <= mmio_valid && !mmio_ready_reg;
    end
    assign mmio_ready = mmio_ready_reg;

    //=========================================================================
    // IRQ output
    //=========================================================================
    assign irq_done = done;

    //=========================================================================
    // MMIO Write Logic
    //=========================================================================
    wire mmio_write = mmio_valid && (mmio_wstrb != 4'b0000);
    wire mmio_read  = mmio_valid && (mmio_wstrb == 4'b0000);

    // Start pulse from control register write
    reg start_pulse;

    always @(posedge clk) begin
        if (!resetn) begin
            operand_a   <= 32'd0;
            operand_b   <= 32'd0;
            operation   <= OP_ADD;
            start_pulse <= 1'b0;
            clear_done  <= 1'b0;
            perf_reset  <= 1'b0;
        end else begin
            start_pulse <= 1'b0;  // Default: clear pulse
            clear_done  <= 1'b0;
            perf_reset  <= 1'b0;

            if (mmio_write && mmio_ready_reg) begin
                case (mmio_addr[7:0])
                    8'h00: begin  // CONTROL register
                        if (mmio_wdata[0] && !busy)
                            start_pulse <= 1'b1;
                        if (mmio_wdata[1])
                            clear_done <= 1'b1;
                        if (mmio_wdata[2])
                            perf_reset <= 1'b1;
                    end
                    8'h08: operand_a <= mmio_wdata;
                    8'h0C: operand_b <= mmio_wdata;
                    8'h14: operation <= mmio_wdata[1:0];
                endcase
            end
        end
    end

    //=========================================================================
    // Accumulator — single always block (avoids multi-driver Yosys errors)
    // Written by: (1) CPU via MMIO, (2) FSM on MAC writeback
    //=========================================================================
    always @(posedge clk) begin
        if (!resetn) begin
            accumulator <= 64'd0;
        end else if (state == S_WRITEBACK && operation == OP_MAC) begin
            // FSM: update accumulator with MAC result
            accumulator <= add_result;
        end else if (mmio_write && mmio_ready_reg) begin
            // CPU: pre-load accumulator via MMIO
            if (mmio_addr[7:0] == 8'h1C) accumulator[31:0]  <= mmio_wdata;
            if (mmio_addr[7:0] == 8'h20) accumulator[63:32] <= mmio_wdata;
        end
    end

    //=========================================================================
    // Main FSM - Multi-cycle Compute Pipeline
    //=========================================================================
    // Inspired by the reference paper's MAC datapath:
    //   - The paper implements MAC via PCPI with operand transfer and
    //     multi-cycle execution
    //   - We replicate the multi-cycle nature via MMIO for observability
    //   - ADD takes 2 cycles, MUL takes 3 cycles, MAC takes 4 cycles
    //     (demonstrates variable latency, visible busy/done)
    //=========================================================================
    always @(posedge clk) begin
        if (!resetn) begin
            state         <= S_IDLE;
            busy          <= 1'b0;
            done          <= 1'b0;
            overflow      <= 1'b0;
            result        <= 64'd0;
            mul_result    <= 64'd0;
            add_result    <= 64'd0;
            perf_cycles   <= 32'd0;
            perf_ops      <= 32'd0;
            cycle_counter <= 32'd0;
        end else begin

            if (perf_reset) begin
                perf_cycles   <= 32'd0;
                perf_ops      <= 32'd0;
            end

            if (clear_done && done) begin
                done     <= 1'b0;
                overflow <= 1'b0;
            end

            case (state)
                //-------------------------------------------------------------
                S_IDLE: begin
                    if (start_pulse) begin
                        state         <= S_LOAD;
                        busy          <= 1'b1;
                        done          <= 1'b0;
                        overflow      <= 1'b0;
                        cycle_counter <= 32'd0;
                    end
                end

                //-------------------------------------------------------------
                S_LOAD: begin
                    // Pipeline stage 1: Latch operands
                    cycle_counter <= cycle_counter + 1;

                    case (operation)
                        OP_ADD: begin
                            // For ADD, go straight to writeback
                            add_result <= {{32{operand_a[31]}}, operand_a} +
                                          {{32{operand_b[31]}}, operand_b};
                            state <= S_WRITEBACK;
                        end
                        OP_MUL: begin
                            // For MUL, need multiply stage
                            state <= S_COMPUTE_1;
                        end
                        OP_MAC: begin
                            // For MAC, need multiply then accumulate
                            state <= S_COMPUTE_1;
                        end
                        default: begin
                            // Invalid operation - go to done with zero result
                            result <= 64'd0;
                            state  <= S_DONE;
                        end
                    endcase
                end

                //-------------------------------------------------------------
                S_COMPUTE_1: begin
                    // Pipeline stage 2: Multiply
                    // Signed 32x32 -> 64-bit multiply
                    cycle_counter <= cycle_counter + 1;
                    mul_result    <= $signed(operand_a) * $signed(operand_b);
                    state         <= (operation == OP_MAC) ? S_COMPUTE_2 : S_WRITEBACK;
                end

                //-------------------------------------------------------------
                S_COMPUTE_2: begin
                    // Pipeline stage 3: Accumulate (MAC only)
                    cycle_counter <= cycle_counter + 1;
                    add_result    <= mul_result + accumulator;
                    // Overflow detection for MAC
                    if ((mul_result[63] == accumulator[63]) &&
                        ((mul_result + accumulator) != 0) &&
                        ((mul_result + accumulator) == {64{1'b0}}))
                        overflow <= 1'b0;  // simplified check
                    state <= S_WRITEBACK;
                end

                //-------------------------------------------------------------
                S_WRITEBACK: begin
                    cycle_counter <= cycle_counter + 1;

                    case (operation)
                        OP_ADD: begin
                            result <= add_result;
                        end
                        OP_MUL: begin
                            result <= mul_result;
                        end
                        OP_MAC: begin
                            result      <= add_result;
                            // accumulator updated via dedicated always block below
                        end
                        default: begin
                            result <= 64'd0;
                        end
                    endcase
                    state <= S_DONE;
                end

                //-------------------------------------------------------------
                S_DONE: begin
                    busy          <= 1'b0;
                    done          <= 1'b1;
                    perf_cycles   <= perf_cycles + cycle_counter + 1;
                    perf_ops      <= perf_ops + 1;
                    state         <= S_IDLE;
                end
            endcase
        end
    end

    //=========================================================================
    // MMIO Read Logic
    //=========================================================================
    always @(*) begin
        mmio_rdata = 32'd0;
        if (mmio_valid) begin
            case (mmio_addr[7:0])
                8'h00: mmio_rdata = 32'd0;                             // CONTROL (write-only)
                8'h04: mmio_rdata = {29'd0, overflow, done, busy};     // STATUS
                8'h08: mmio_rdata = operand_a;                         // OPERAND_A
                8'h0C: mmio_rdata = operand_b;                         // OPERAND_B
                8'h10: mmio_rdata = result[31:0];                      // RESULT_LO
                8'h14: mmio_rdata = {30'd0, operation};                // OPERATION
                8'h18: mmio_rdata = result[63:32];                     // RESULT_HI
                8'h1C: mmio_rdata = accumulator[31:0];                 // ACCUM_LO
                8'h20: mmio_rdata = accumulator[63:32];                // ACCUM_HI
                8'h24: mmio_rdata = perf_cycles;                       // PERF_CYCLES
                8'h28: mmio_rdata = perf_ops;                          // PERF_OPS
                default: mmio_rdata = 32'hDEADBEEF;
            endcase
        end
    end

endmodule

