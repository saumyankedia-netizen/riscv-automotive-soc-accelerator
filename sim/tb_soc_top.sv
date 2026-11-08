`timescale 1ns / 1ps
//=============================================================================
// Testbench for SoC with Dummy MAC Accelerator
//-----------------------------------------------------------------------------
// This testbench:
//   1. Instantiates the full SoC (PicoRV32 + MMIO decoder + accelerator)
//   2. Loads firmware that exercises ADD, MUL, and MAC operations
//   3. Monitors GPIO output and accelerator status
//   4. Compares accelerator results against expected values
//   5. Measures and reports cycle counts for speedup analysis
//
// Reference: "Design and Implementation of a Custom Multiply Accumulate
//            Instruction in an Open-Source RISC-V Processor Core"
//            (DOI: 10.1109/ICCPCT70290.2026.11654754)
//=============================================================================

module tb_soc_top;

    //=========================================================================
    // Parameters
    //=========================================================================
    parameter CLK_PERIOD = 20;      // 50 MHz clock
    parameter TIMEOUT    = 500000;  // Simulation timeout (ns)

    //=========================================================================
    // Signals
    //=========================================================================
    reg         clk;
    reg         resetn;
    wire [31:0] gpio_out;
    wire        trap;
    wire        accel_irq_done;

    //=========================================================================
    // Clock generation
    //=========================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    //=========================================================================
    // DUT instantiation
    //=========================================================================
    soc_top #(
        .MEM_SIZE_BYTES(16384),
        .FIRMWARE_FILE ("")
    ) dut (
        .clk           (clk),
        .resetn        (resetn),
        .gpio_out      (gpio_out),
        .trap          (trap),
        .accel_irq_done(accel_irq_done)
    );

    //=========================================================================
    // Firmware loading - directly write RISC-V machine code into SRAM
    //=========================================================================
    // This is more reliable than a hex file: we write correct RV32I
    // instructions directly into the memory array.
    //
    // The firmware:
    //   1. Writes operands to accelerator via MMIO
    //   2. Starts operation, polls for done
    //   3. Reads result, writes it to GPIO
    //   4. Repeats for ADD, MUL, MAC
    //   5. Reads perf counters, writes magic "done" value to GPIO
    //=========================================================================
    task load_firmware;
        integer i;
        begin
            // Clear memory
            for (i = 0; i < 4096; i = i + 1)
                dut.memory[i] = 32'h00000013; // NOP

            // ================================================================
            // RESET VECTOR at 0x0000 - Jump to main at 0x0100
            // ================================================================
            // jal x0, 0x100  (J-type: offset=256=0x100)
            // J-type: imm[20|10:1|11|19:12] rd opcode
            // offset=0x100 => binary: 0_00_0000_0001_0000_0000_0
            // imm[20]=0, imm[19:12]=0x00, imm[11]=1, imm[10:1]=0x80
            // Encoding: 0_1000000000_1_00000000_00000_1101111
            // = 0000_0000_0000_0000_0001_0000_0000_0000_0110_1111
            // Wait - let me compute properly:
            // offset = 0x100 = 256
            // imm[20]    = 0
            // imm[10:1]  = (0x100 >> 1) & 0x3FF = 0x80 = 10_0000_0000
            // imm[11]    = (0x100 >> 11) & 1 = 0
            // imm[19:12] = (0x100 >> 12) & 0xFF = 0
            // Encoded: {0, 10_0000_0000, 0, 0000_0000} = 0x10000
            // Full: {0x10000, 5'd0, 7'b1101111} = 0x1000006F
            dut.memory[0] = 32'h1000006F;  // jal x0, 0x100

            // ================================================================
            // IRQ VECTOR at 0x0010 (word address 4)
            // Simple IRQ handler: just return
            // ================================================================
            // The IRQ system needs: getq, retirq etc.
            // For simplicity we leave NOPs (IRQ won't fire during test since
            // we don't unmask IRQs in firmware)

            // ================================================================
            // MAIN at 0x0100 (word address 64)
            // ================================================================
            i = 64;  // Start at word address 64 = byte address 0x100

            // --- Setup base addresses ---
            // lui x3, 0x10000    ; x3 = 0x10000000 (ACCEL base)
            dut.memory[i] = 32'h100001B7; i=i+1;
            // lui x4, 0x20000    ; x4 = 0x20000000 (GPIO base)
            dut.memory[i] = 32'h20000237; i=i+1;

            // ============================================================
            // TEST 1: Accelerator ADD (12 + 7 = 19)
            // ============================================================
            // addi x5, x0, 12   ; x5 = 12
            dut.memory[i] = 32'h00C00293; i=i+1;
            // sw x5, 0x08(x3)   ; OPERAND_A = 12
            dut.memory[i] = 32'h0051A423; i=i+1;
            // addi x5, x0, 7    ; x5 = 7
            dut.memory[i] = 32'h00700293; i=i+1;
            // sw x5, 0x0C(x3)   ; OPERAND_B = 7
            dut.memory[i] = 32'h0051A623; i=i+1;
            // addi x5, x0, 0    ; operation = ADD
            dut.memory[i] = 32'h00000293; i=i+1;
            // sw x5, 0x14(x3)   ; OPERATION = 0 (ADD)
            dut.memory[i] = 32'h0051AA23; i=i+1;

            // rdcycle x16  ; snapshot cycle counter BEFORE accel
            dut.memory[i] = 32'hC0002873; i=i+1;

            // addi x5, x0, 1    ; start=1
            dut.memory[i] = 32'h00100293; i=i+1;
            // sw x5, 0x00(x3)   ; CONTROL = start
            dut.memory[i] = 32'h0051A023; i=i+1;

            // Poll STATUS until done (bit 1)
            // poll_add: (this is word address i)
            // lw x5, 0x04(x3)
            dut.memory[i] = 32'h0041A283; i=i+1;
            // andi x5, x5, 2 (rs1=x5, rd=x5, imm=2)
            dut.memory[i] = 32'h0022F293; i=i+1;
            // beq x5, x0, -8 (back to lw)
            dut.memory[i] = 32'hFE028CE3; i=i+1;

            // rdcycle x17 ; snapshot AFTER accel done
            dut.memory[i] = 32'hC00028F3; i=i+1;

            // lw x6, 0x10(x3)   ; Read RESULT_LO
            dut.memory[i] = 32'h0101A303; i=i+1;
            // sw x6, 0x00(x4)   ; GPIO = result (expect 19)
            dut.memory[i] = 32'h00622023; i=i+1;

            // sub x18, x17, x16  ; x18 = accel_cycles
            dut.memory[i] = 32'h41080933; i=i+1;

            // clear done: addi x5, x0, 2
            dut.memory[i] = 32'h00200293; i=i+1;
            // sw x5, 0x00(x3)
            dut.memory[i] = 32'h0051A023; i=i+1;

            // ============================================================
            // TEST 1b: Software ADD for comparison (12 + 7)
            // ============================================================
            // rdcycle x16
            dut.memory[i] = 32'hC0002873; i=i+1;
            // addi x5, x0, 12
            dut.memory[i] = 32'h00C00293; i=i+1;
            // addi x6, x0, 7
            dut.memory[i] = 32'h00700313; i=i+1;
            // add x7, x5, x6
            dut.memory[i] = 32'h006283B3; i=i+1;
            // rdcycle x17
            dut.memory[i] = 32'hC00028F3; i=i+1;
            // sub x19, x17, x16  ; x19 = sw_cycles for ADD
            dut.memory[i] = 32'h410889B3; i=i+1;
            // sw x7, 0x00(x4)   ; GPIO = sw ADD result (expect 19)
            dut.memory[i] = 32'h00722023; i=i+1;

            // ============================================================
            // TEST 2: Accelerator MUL (12 * 7 = 84)
            // ============================================================
            // addi x5, x0, 12
            dut.memory[i] = 32'h00C00293; i=i+1;
            // sw x5, 0x08(x3)
            dut.memory[i] = 32'h0051A423; i=i+1;
            // addi x5, x0, 7
            dut.memory[i] = 32'h00700293; i=i+1;
            // sw x5, 0x0C(x3)
            dut.memory[i] = 32'h0051A623; i=i+1;
            // addi x5, x0, 1   ; operation = MUL
            dut.memory[i] = 32'h00100293; i=i+1;
            // sw x5, 0x14(x3)
            dut.memory[i] = 32'h0051AA23; i=i+1;

            // rdcycle x16
            dut.memory[i] = 32'hC0002873; i=i+1;

            // start
            // addi x5, x0, 1
            dut.memory[i] = 32'h00100293; i=i+1;
            // sw x5, 0x00(x3)
            dut.memory[i] = 32'h0051A023; i=i+1;

            // Poll
            dut.memory[i] = 32'h0041A283; i=i+1;  // lw x5, 0x04(x3)
            dut.memory[i] = 32'h0022F293; i=i+1;  // andi x5, x5, 2
            dut.memory[i] = 32'hFE028CE3; i=i+1;  // beq x5, x0, -8

            // rdcycle x17
            dut.memory[i] = 32'hC00028F3; i=i+1;

            // lw x6, 0x10(x3)  ; RESULT_LO
            dut.memory[i] = 32'h0101A303; i=i+1;
            // sw x6, 0x00(x4)  ; GPIO (expect 84)
            dut.memory[i] = 32'h00622023; i=i+1;

            // sub x20, x17, x16 ; accel MUL cycles
            dut.memory[i] = 32'h41080A33; i=i+1;

            // clear done
            dut.memory[i] = 32'h00200293; i=i+1;
            dut.memory[i] = 32'h0051A023; i=i+1;

            // ============================================================
            // TEST 2b: Software MUL for comparison (12 * 7 via shifts/adds)
            // ============================================================
            // Software multiply using shift-and-add (since no MUL instr)
            // 12 * 7 = 12 * (4 + 2 + 1) = 48 + 24 + 12 = 84
            // rdcycle x16
            dut.memory[i] = 32'hC0002873; i=i+1;
            // addi x5, x0, 12   ; multiplicand
            dut.memory[i] = 32'h00C00293; i=i+1;
            // addi x6, x0, 7    ; multiplier
            dut.memory[i] = 32'h00700313; i=i+1;
            // addi x7, x0, 0    ; product = 0
            dut.memory[i] = 32'h00000393; i=i+1;

            // Software multiply loop (8 iterations for 8-bit multiplier)
            // sw_mul_loop:
            // andi x8, x6, 1    ; test LSB
            dut.memory[i] = 32'h00137413; i=i+1;
            // beq x8, x0, skip_add (skip 1 instr = +8)
            dut.memory[i] = 32'h00040463; i=i+1;
            // add x7, x7, x5    ; product += multiplicand
            dut.memory[i] = 32'h005383B3; i=i+1;
            // skip_add:
            // slli x5, x5, 1    ; multiplicand <<= 1
            dut.memory[i] = 32'h00129293; i=i+1;
            // srli x6, x6, 1    ; multiplier >>= 1
            dut.memory[i] = 32'h00135313; i=i+1;
            // bne x6, x0, sw_mul_loop (-20)
            dut.memory[i] = 32'hFE031CE3; i=i+1;

            // rdcycle x17
            dut.memory[i] = 32'hC00028F3; i=i+1;
            // sub x21, x17, x16 ; sw MUL cycles
            dut.memory[i] = 32'h41088AB3; i=i+1;
            // sw x7, 0x00(x4)   ; GPIO = sw MUL result
            dut.memory[i] = 32'h00722023; i=i+1;

            // ============================================================
            // TEST 3: Accelerator MAC (3*4 + 5*6 = 12 + 30 = 42)
            // ============================================================
            // Clear accumulator
            // addi x5, x0, 0
            dut.memory[i] = 32'h00000293; i=i+1;
            // sw x5, 0x1C(x3)  ; ACCUM_LO = 0
            dut.memory[i] = 32'h0051AE23; i=i+1;
            // sw x5, 0x20(x3)  ; ACCUM_HI = 0
            // Encoding: sw x5, 0x20(x3) => imm[11:5]=0x01, rs2=5, rs1=3, f3=010, imm[4:0]=0x00
            dut.memory[i] = {7'b0000001, 5'd5, 5'd3, 3'b010, 5'b00000, 7'b0100011}; i=i+1;

            // rdcycle x16
            dut.memory[i] = 32'hC0002873; i=i+1;

            // MAC1: 3 * 4
            // addi x5, x0, 3
            dut.memory[i] = 32'h00300293; i=i+1;
            // sw x5, 0x08(x3)
            dut.memory[i] = 32'h0051A423; i=i+1;
            // addi x5, x0, 4
            dut.memory[i] = 32'h00400293; i=i+1;
            // sw x5, 0x0C(x3)
            dut.memory[i] = 32'h0051A623; i=i+1;
            // addi x5, x0, 2   ; MAC
            dut.memory[i] = 32'h00200293; i=i+1;
            // sw x5, 0x14(x3)
            dut.memory[i] = 32'h0051AA23; i=i+1;
            // start
            dut.memory[i] = 32'h00100293; i=i+1;
            dut.memory[i] = 32'h0051A023; i=i+1;
            // poll
            dut.memory[i] = 32'h0041A283; i=i+1;
            dut.memory[i] = 32'h0022F293; i=i+1;
            dut.memory[i] = 32'hFE028CE3; i=i+1;
            // clear done
            dut.memory[i] = 32'h00200293; i=i+1;
            dut.memory[i] = 32'h0051A023; i=i+1;

            // MAC2: 5 * 6
            dut.memory[i] = 32'h00500293; i=i+1;  // addi x5, x0, 5
            dut.memory[i] = 32'h0051A423; i=i+1;  // sw x5, 0x08(x3)
            dut.memory[i] = 32'h00600293; i=i+1;  // addi x5, x0, 6
            dut.memory[i] = 32'h0051A623; i=i+1;  // sw x5, 0x0C(x3)
            // operation still MAC
            dut.memory[i] = 32'h00100293; i=i+1;  // start
            dut.memory[i] = 32'h0051A023; i=i+1;
            // poll
            dut.memory[i] = 32'h0041A283; i=i+1;
            dut.memory[i] = 32'h0022F293; i=i+1;
            dut.memory[i] = 32'hFE028CE3; i=i+1;

            // rdcycle x17
            dut.memory[i] = 32'hC00028F3; i=i+1;
            // sub x22, x17, x16 ; accel MAC cycles
            dut.memory[i] = 32'h41088B33; i=i+1;

            // lw x6, 0x10(x3)  ; RESULT_LO (expect 42)
            dut.memory[i] = 32'h0101A303; i=i+1;
            // sw x6, 0x00(x4)
            dut.memory[i] = 32'h00622023; i=i+1;

            // ============================================================
            // TEST 4: Read accelerator performance counters
            // ============================================================
            // lw x14, 0x24(x3) ; PERF_CYCLES
            dut.memory[i] = 32'h0241A703; i=i+1;
            // lw x15, 0x28(x3) ; PERF_OPS
            dut.memory[i] = 32'h0281A783; i=i+1;
            // sw x14, 0x00(x4)
            dut.memory[i] = 32'h00E22023; i=i+1;

            // ============================================================
            // DONE: Write magic value 0x0000_DEAD to GPIO
            // ============================================================
            // lui x5, 0x0000E   ; x5 = 0x0000E000 (close enough)
            dut.memory[i] = 32'h0000E2B7; i=i+1;
            // addi x5, x5, -291 ; 0x0000E000 - 291 = adjust
            // Let's just use: addi x5, x0, 0x5A5  (a recognizable pattern)
            // Actually, let's use lui + addi for 0xDEAD:
            // 0xDEAD = 57005
            // lui x5, 0xE ; x5 = 0xE000
            // addi x5, x5, 0xEAD = -339 (0xFFFFFEAD sign ext)
            // That won't work easily. Just use a simpler magic value.

            // addi x5, x0, 0x42  ; magic = 0x42 ("B" for "done")
            dut.memory[i] = 32'h04200293; i=i+1;
            // Actually use 0x600D ("GOOD")
            // Let's just write the cycle counts to GPIO instead:
            // sw x18, 0x00(x4)  ; GPIO = accel ADD cycles
            dut.memory[i] = 32'h01222023; i=i+1;

            // Final halt: jal x0, 0  (infinite loop)
            dut.memory[i] = 32'h0000006F; i=i+1;

            $display("[FIRMWARE] Loaded %0d instructions", i);
        end
    endtask

    //=========================================================================
    // Test monitoring
    //=========================================================================
    reg [31:0] prev_gpio;
    integer    gpio_change_count;
    integer    test_pass_count;
    integer    test_fail_count;

    // Track accelerator state
    reg [31:0] cycle_at_start;
    reg [31:0] cycle_at_done;

    // Expected results
    localparam EXPECTED_ADD = 32'd19;   // 12 + 7
    localparam EXPECTED_MUL = 32'd84;   // 12 * 7
    localparam EXPECTED_MAC = 32'd42;   // 3*4 + 5*6

    initial begin
        prev_gpio = 0;
        gpio_change_count = 0;
        test_pass_count = 0;
        test_fail_count = 0;
    end

    // Monitor GPIO changes (firmware writes results here)
    always @(posedge clk) begin
        if (gpio_out !== prev_gpio && resetn) begin
            gpio_change_count = gpio_change_count + 1;
            $display("[GPIO] Time=%0t Change #%0d: 0x%08X (%0d)",
                     $time, gpio_change_count, gpio_out, gpio_out);

            case (gpio_change_count)
                1: begin  // ADD result
                    if (gpio_out == EXPECTED_ADD) begin
                        $display("[PASS] TEST 1 - Accelerator ADD: 12 + 7 = %0d (expected %0d)",
                                 gpio_out, EXPECTED_ADD);
                        test_pass_count = test_pass_count + 1;
                    end else begin
                        $display("[FAIL] TEST 1 - Accelerator ADD: got %0d, expected %0d",
                                 gpio_out, EXPECTED_ADD);
                        test_fail_count = test_fail_count + 1;
                    end
                end
                2: begin  // SW ADD result
                    if (gpio_out == EXPECTED_ADD) begin
                        $display("[PASS] TEST 1b - Software ADD: 12 + 7 = %0d", gpio_out);
                        test_pass_count = test_pass_count + 1;
                    end else begin
                        $display("[FAIL] TEST 1b - Software ADD: got %0d, expected %0d",
                                 gpio_out, EXPECTED_ADD);
                        test_fail_count = test_fail_count + 1;
                    end
                end
                3: begin  // MUL result
                    if (gpio_out == EXPECTED_MUL) begin
                        $display("[PASS] TEST 2 - Accelerator MUL: 12 * 7 = %0d (expected %0d)",
                                 gpio_out, EXPECTED_MUL);
                        test_pass_count = test_pass_count + 1;
                    end else begin
                        $display("[FAIL] TEST 2 - Accelerator MUL: got %0d, expected %0d",
                                 gpio_out, EXPECTED_MUL);
                        test_fail_count = test_fail_count + 1;
                    end
                end
                4: begin  // SW MUL result
                    if (gpio_out == EXPECTED_MUL) begin
                        $display("[PASS] TEST 2b - Software MUL: 12 * 7 = %0d", gpio_out);
                        test_pass_count = test_pass_count + 1;
                    end else begin
                        $display("[FAIL] TEST 2b - Software MUL: got %0d, expected %0d",
                                 gpio_out, EXPECTED_MUL);
                        test_fail_count = test_fail_count + 1;
                    end
                end
                5: begin  // MAC result
                    if (gpio_out == EXPECTED_MAC) begin
                        $display("[PASS] TEST 3 - Accelerator MAC: 3*4 + 5*6 = %0d (expected %0d)",
                                 gpio_out, EXPECTED_MAC);
                        test_pass_count = test_pass_count + 1;
                    end else begin
                        $display("[FAIL] TEST 3 - Accelerator MAC: got %0d, expected %0d",
                                 gpio_out, EXPECTED_MAC);
                        test_fail_count = test_fail_count + 1;
                    end
                end
                6: begin  // Performance counter (accel total cycles)
                    $display("[INFO] Accelerator total compute cycles: %0d", gpio_out);
                end
                7: begin  // Final marker (accel ADD cycles via register)
                    $display("[INFO] Accel ADD cycle measurement: %0d CPU cycles", gpio_out);
                end
            endcase

            prev_gpio = gpio_out;
        end
    end

    // Monitor accelerator busy/done transitions
    always @(posedge clk) begin
        if (dut.accel.busy && !dut.accel.done)
            $display("[ACCEL] Time=%0t BUSY - Operation: %s",
                     $time,
                     dut.accel.operation == 2'b00 ? "ADD" :
                     dut.accel.operation == 2'b01 ? "MUL" :
                     dut.accel.operation == 2'b10 ? "MAC" : "???");
    end

    reg prev_done;
    always @(posedge clk) begin
        prev_done <= dut.accel.done;
        if (dut.accel.done && !prev_done)
            $display("[ACCEL] Time=%0t DONE - Result: 0x%08X_%08X  Perf: %0d cycles, %0d ops",
                     $time, dut.accel.result[63:32], dut.accel.result[31:0],
                     dut.accel.perf_cycles, dut.accel.perf_ops);
    end

    //=========================================================================
    // Trap detection
    //=========================================================================
    always @(posedge clk) begin
        if (trap) begin
            $display("\n[TRAP] CPU trapped at time %0t!", $time);
            $display("[TRAP] PC = 0x%08X", dut.cpu.reg_pc);
            #100;
            print_summary();
            $finish;
        end
    end

    //=========================================================================
    // Test completion detection
    //=========================================================================
    // Detect infinite loop (CPU executing same PC repeatedly)
    reg [31:0] prev_pc;
    integer    same_pc_count;

    always @(posedge clk) begin
        if (resetn) begin
            if (dut.cpu.reg_pc == prev_pc)
                same_pc_count <= same_pc_count + 1;
            else
                same_pc_count <= 0;
            prev_pc <= dut.cpu.reg_pc;

            if (same_pc_count > 50) begin
                $display("\n[HALT] Detected halt loop at PC=0x%08X at time %0t",
                         dut.cpu.reg_pc, $time);
                #100;
                print_summary();
                $finish;
            end
        end
    end

    //=========================================================================
    // Summary report
    //=========================================================================
    task print_summary;
        begin
            $display("");
            $display("================================================================");
            $display("  SoC DUMMY ACCELERATOR TEST SUMMARY");
            $display("================================================================");
            $display("  Tests Passed : %0d", test_pass_count);
            $display("  Tests Failed : %0d", test_fail_count);
            $display("  GPIO Changes : %0d", gpio_change_count);
            $display("");
            $display("  --- Accelerator Performance Counters ---");
            $display("  Total Accel Compute Cycles : %0d", dut.accel.perf_cycles);
            $display("  Total Accel Operations     : %0d", dut.accel.perf_ops);
            if (dut.accel.perf_ops > 0)
                $display("  Avg Cycles per Operation   : %0d",
                         dut.accel.perf_cycles / dut.accel.perf_ops);
            $display("");
            $display("  --- CPU Register File (selected) ---");
            $display("  x3  (ACCEL base) = 0x%08X", dut.cpu.cpuregs[3]);
            $display("  x4  (GPIO base)  = 0x%08X", dut.cpu.cpuregs[4]);
            $display("  x18 (accel ADD cy) = %0d",  dut.cpu.cpuregs[18]);
            $display("  x19 (sw ADD cy)    = %0d",  dut.cpu.cpuregs[19]);
            $display("  x20 (accel MUL cy) = %0d",  dut.cpu.cpuregs[20]);
            $display("  x21 (sw MUL cy)    = %0d",  dut.cpu.cpuregs[21]);
            $display("  x22 (accel MAC cy) = %0d",  dut.cpu.cpuregs[22]);
            $display("");

            // Speedup analysis
            if (dut.cpu.cpuregs[19] > 0 && dut.cpu.cpuregs[18] > 0) begin
                $display("  --- Speedup Analysis ---");
                $display("  ADD: Accel=%0d cy, Software=%0d cy",
                         dut.cpu.cpuregs[18], dut.cpu.cpuregs[19]);
                if (dut.cpu.cpuregs[18] < dut.cpu.cpuregs[19])
                    $display("  ADD Speedup: Software is ~%0dx slower",
                             dut.cpu.cpuregs[19] / dut.cpu.cpuregs[18]);
                else
                    $display("  ADD: Accelerator overhead > software (expected for simple ADD)");
            end
            if (dut.cpu.cpuregs[21] > 0 && dut.cpu.cpuregs[20] > 0) begin
                $display("  MUL: Accel=%0d cy, Software=%0d cy",
                         dut.cpu.cpuregs[20], dut.cpu.cpuregs[21]);
                if (dut.cpu.cpuregs[20] < dut.cpu.cpuregs[21])
                    $display("  MUL Speedup: Software is ~%0dx slower",
                             dut.cpu.cpuregs[21] / dut.cpu.cpuregs[20]);
                else
                    $display("  MUL: Accel takes more cycles (MMIO overhead)");
            end

            $display("================================================================");
            if (test_fail_count == 0 && test_pass_count > 0)
                $display("  RESULT: ALL TESTS PASSED");
            else if (test_fail_count > 0)
                $display("  RESULT: SOME TESTS FAILED");
            else
                $display("  RESULT: NO TESTS COMPLETED (possible firmware issue)");
            $display("================================================================");
        end
    endtask

    //=========================================================================
    // Main test sequence
    //=========================================================================
    initial begin
        $display("================================================================");
        $display("  PicoRV32 SoC + Dummy MAC Accelerator Testbench");
        $display("  Clock period: %0d ns (%0d MHz)", CLK_PERIOD, 1000/CLK_PERIOD);
        $display("================================================================");

        // Waveform dump
        $dumpfile("soc_top_tb.vcd");
        $dumpvars(0, tb_soc_top);

        // Initialize
        resetn = 0;
        same_pc_count = 0;
        prev_pc = 0;
        prev_done = 0;

        // Load firmware
        load_firmware();

        // Release reset
        #(CLK_PERIOD * 10);
        resetn = 1;
        $display("[SIM] Reset released at time %0t", $time);

        // Timeout
        #(TIMEOUT);
        $display("\n[TIMEOUT] Simulation timed out at %0t", $time);
        print_summary();
        $finish;
    end

endmodule
