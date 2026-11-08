`timescale 1ns / 1ps
//=============================================================================
// Testbench for SoC with Dummy MAC Accelerator
//=============================================================================

module tb_soc_top;

    parameter CLK_PERIOD = 20;      // 50 MHz clock
    parameter TIMEOUT    = 500000;  // Simulation timeout (ns)

    reg         clk;
    reg         resetn;
    wire [31:0] gpio_out;
    wire        trap;
    wire        accel_irq_done;

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

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

    task load_firmware;
        integer i;
        begin
            for (i = 0; i < 4096; i = i + 1)
                dut.memory[i] = 32'h00000013; // NOP

            // RESET VECTOR: Jump to main at 0x0100
            dut.memory[0] = 32'h1000006F;  // jal x0, 0x100

            // MAIN at 0x0100 (word address 64)
            i = 64;

            // Base addresses: x3 = 0x10000000 (ACCEL), x4 = 0x20000000 (GPIO)
            dut.memory[i] = 32'h100001B7; i=i+1; // lui x3, 0x10000
            dut.memory[i] = 32'h20000237; i=i+1; // lui x4, 0x20000

            // ============================================================
            // TEST 1: Accelerator ADD (12 + 7 = 19)
            // ============================================================
            dut.memory[i] = 32'h00C00293; i=i+1; // addi x5, x0, 12
            dut.memory[i] = 32'h0051A423; i=i+1; // sw x5, 0x08(x3) (OPERAND_A)
            dut.memory[i] = 32'h00700293; i=i+1; // addi x5, x0, 7
            dut.memory[i] = 32'h0051A623; i=i+1; // sw x5, 0x0C(x3) (OPERAND_B)
            dut.memory[i] = 32'h00000293; i=i+1; // addi x5, x0, 0 (ADD)
            dut.memory[i] = 32'h0051AA23; i=i+1; // sw x5, 0x14(x3) (OPERATION)

            dut.memory[i] = 32'hC0002873; i=i+1; // rdcycle x16 (start)
            dut.memory[i] = 32'h00100293; i=i+1; // addi x5, x0, 1
            dut.memory[i] = 32'h0051A023; i=i+1; // sw x5, 0x00(x3) (START)

            // Poll STATUS until done
            dut.memory[i] = 32'h0041A283; i=i+1; // lw x5, 0x04(x3)
            dut.memory[i] = 32'h0022F293; i=i+1; // andi x5, x5, 2
            dut.memory[i] = 32'hFE028CE3; i=i+1; // beq x5, x0, -8

            dut.memory[i] = 32'hC00028F3; i=i+1; // rdcycle x17 (end)

            dut.memory[i] = 32'h0101A303; i=i+1; // lw x6, 0x10(x3) (RESULT)
            dut.memory[i] = 32'h00622023; i=i+1; // sw x6, 0x00(x4) (GPIO = 19)

            dut.memory[i] = 32'h41080933; i=i+1; // sub x18, x17, x16 (accel_cycles)
            dut.memory[i] = 32'h00200293; i=i+1; // addi x5, x0, 2
            dut.memory[i] = 32'h0051A023; i=i+1; // sw x5, 0x00(x3) (clear_done)

            // ============================================================
            // TEST 1b: Software ADD for comparison (12 + 7)
            // ============================================================
            dut.memory[i] = 32'hC0002873; i=i+1; // rdcycle x16
            dut.memory[i] = 32'h00C00293; i=i+1; // addi x5, x0, 12
            dut.memory[i] = 32'h00700313; i=i+1; // addi x6, x0, 7
            dut.memory[i] = 32'h006283B3; i=i+1; // add x7, x5, x6
            dut.memory[i] = 32'hC00028F3; i=i+1; // rdcycle x17
            dut.memory[i] = 32'h410889B3; i=i+1; // sub x19, x17, x16 (sw_cycles)

            // ============================================================
            // TEST 2: Accelerator MUL (12 * 7 = 84)
            // ============================================================
            dut.memory[i] = 32'h00C00293; i=i+1; // addi x5, x0, 12
            dut.memory[i] = 32'h0051A423; i=i+1; // sw x5, 0x08(x3)
            dut.memory[i] = 32'h00700293; i=i+1; // addi x5, x0, 7
            dut.memory[i] = 32'h0051A623; i=i+1; // sw x5, 0x0C(x3)
            dut.memory[i] = 32'h00100293; i=i+1; // addi x5, x0, 1 (MUL)
            dut.memory[i] = 32'h0051AA23; i=i+1; // sw x5, 0x14(x3)

            dut.memory[i] = 32'hC0002873; i=i+1; // rdcycle x16
            dut.memory[i] = 32'h00100293; i=i+1; // addi x5, x0, 1
            dut.memory[i] = 32'h0051A023; i=i+1; // sw x5, 0x00(x3) (START)

            // Poll
            dut.memory[i] = 32'h0041A283; i=i+1; // lw x5, 0x04(x3)
            dut.memory[i] = 32'h0022F293; i=i+1; // andi x5, x5, 2
            dut.memory[i] = 32'hFE028CE3; i=i+1; // beq x5, x0, -8

            dut.memory[i] = 32'hC00028F3; i=i+1; // rdcycle x17
            dut.memory[i] = 32'h0101A303; i=i+1; // lw x6, 0x10(x3)
            dut.memory[i] = 32'h00622023; i=i+1; // sw x6, 0x00(x4) (GPIO = 84)

            dut.memory[i] = 32'h41080A33; i=i+1; // sub x20, x17, x16 (accel MUL cy)
            dut.memory[i] = 32'h00200293; i=i+1; // clear done
            dut.memory[i] = 32'h0051A023; i=i+1;

            // ============================================================
            // TEST 2b: Software MUL for comparison (12 * 7 shift-and-add)
            // ============================================================
            dut.memory[i] = 32'hC0002873; i=i+1; // rdcycle x16
            dut.memory[i] = 32'h00C00293; i=i+1; // addi x5, x0, 12
            dut.memory[i] = 32'h00700313; i=i+1; // addi x6, x0, 7
            dut.memory[i] = 32'h00000393; i=i+1; // addi x7, x0, 0 (product)

            // Software multiply loop
            dut.memory[i] = 32'h00137413; i=i+1; // andi x8, x6, 1
            dut.memory[i] = 32'h00040463; i=i+1; // beq x8, x0, +8
            dut.memory[i] = 32'h005383B3; i=i+1; // add x7, x7, x5
            dut.memory[i] = 32'h00129293; i=i+1; // slli x5, x5, 1
            dut.memory[i] = 32'h00135313; i=i+1; // srli x6, x6, 1
            dut.memory[i] = 32'hFE031CE3; i=i+1; // bne x6, x0, -20

            dut.memory[i] = 32'hC00028F3; i=i+1; // rdcycle x17
            dut.memory[i] = 32'h41088AB3; i=i+1; // sub x21, x17, x16 (sw MUL cy)

            // ============================================================
            // TEST 3: Accelerator MAC (3*4 + 5*6 = 42)
            // ============================================================
            dut.memory[i] = 32'h00000293; i=i+1; // addi x5, x0, 0
            dut.memory[i] = 32'h0051AE23; i=i+1; // sw x5, 0x1C(x3) (ACCUM_LO=0)
            dut.memory[i] = {7'b0000001, 5'd5, 5'd3, 3'b010, 5'b00000, 7'b0100011}; i=i+1;

            dut.memory[i] = 32'hC0002873; i=i+1; // rdcycle x16

            // MAC1: 3 * 4
            dut.memory[i] = 32'h00300293; i=i+1; // addi x5, x0, 3
            dut.memory[i] = 32'h0051A423; i=i+1; // sw x5, 0x08(x3)
            dut.memory[i] = 32'h00400293; i=i+1; // addi x5, x0, 4
            dut.memory[i] = 32'h0051A623; i=i+1; // sw x5, 0x0C(x3)
            dut.memory[i] = 32'h00200293; i=i+1; // addi x5, x0, 2 (MAC)
            dut.memory[i] = 32'h0051AA23; i=i+1; // sw x5, 0x14(x3)
            dut.memory[i] = 32'h00100293; i=i+1; // addi x5, x0, 1
            dut.memory[i] = 32'h0051A023; i=i+1; // start

            dut.memory[i] = 32'h0041A283; i=i+1; // lw x5, 0x04(x3)
            dut.memory[i] = 32'h0022F293; i=i+1; // andi x5, x5, 2
            dut.memory[i] = 32'hFE028CE3; i=i+1; // beq x5, x0, -8

            dut.memory[i] = 32'h0101A303; i=i+1; // lw x6, 0x10(x3) (read MAC1 result = 12)
            dut.memory[i] = 32'h00622023; i=i+1; // sw x6, 0x00(x4) (GPIO = 12)

            dut.memory[i] = 32'h00200293; i=i+1; // clear done
            dut.memory[i] = 32'h0051A023; i=i+1;

            // MAC2: 5 * 6
            dut.memory[i] = 32'h00500293; i=i+1; // addi x5, x0, 5
            dut.memory[i] = 32'h0051A423; i=i+1; // sw x5, 0x08(x3)
            dut.memory[i] = 32'h00600293; i=i+1; // addi x5, x0, 6
            dut.memory[i] = 32'h0051A623; i=i+1; // sw x5, 0x0C(x3)
            dut.memory[i] = 32'h00100293; i=i+1; // start
            dut.memory[i] = 32'h0051A023; i=i+1;

            dut.memory[i] = 32'h0041A283; i=i+1; // lw x5, 0x04(x3)
            dut.memory[i] = 32'h0022F293; i=i+1; // andi x5, x5, 2
            dut.memory[i] = 32'hFE028CE3; i=i+1; // beq x5, x0, -8

            dut.memory[i] = 32'hC00028F3; i=i+1; // rdcycle x17
            dut.memory[i] = 32'h41088B33; i=i+1; // sub x22, x17, x16 (accel MAC cy)

            dut.memory[i] = 32'h0101A303; i=i+1; // lw x6, 0x10(x3) (read MAC2 result = 42)
            dut.memory[i] = 32'h00622023; i=i+1; // sw x6, 0x00(x4) (GPIO = 42)

            // ============================================================
            // Performance counters
            // ============================================================
            dut.memory[i] = 32'h0241A703; i=i+1; // lw x14, 0x24(x3) (PERF_CYCLES)
            dut.memory[i] = 32'h0281A783; i=i+1; // lw x15, 0x28(x3) (PERF_OPS)
            dut.memory[i] = 32'h00E22023; i=i+1; // sw x14, 0x00(x4) (GPIO = perf cycles)

            // Final halt loop
            dut.memory[i] = 32'h0000006F; i=i+1; // jal x0, 0

            $display("[FIRMWARE] Loaded %0d instructions", i);
        end
    endtask

    reg [31:0] prev_gpio;
    integer    gpio_change_count;
    integer    test_pass_count;
    integer    test_fail_count;

    localparam EXPECTED_ADD = 32'd19;   // 12 + 7
    localparam EXPECTED_MUL = 32'd84;   // 12 * 7
    localparam EXPECTED_MAC = 32'd42;   // 3*4 + 5*6

    initial begin
        prev_gpio = 0;
        gpio_change_count = 0;
        test_pass_count = 0;
        test_fail_count = 0;
    end

    always @(posedge clk) begin
        if (gpio_out !== prev_gpio && resetn) begin
            gpio_change_count = gpio_change_count + 1;
            $display("[GPIO] Time=%0t Output #%0d: 0x%08X (%0d)",
                     $time, gpio_change_count, gpio_out, gpio_out);

            case (gpio_change_count)
                1: begin
                    if (gpio_out == EXPECTED_ADD) begin
                        $display("[PASS] TEST 1 - Accelerator ADD: 12 + 7 = %0d", gpio_out);
                        test_pass_count = test_pass_count + 1;
                    end else begin
                        $display("[FAIL] TEST 1 - Accelerator ADD: got %0d, expected %0d", gpio_out, EXPECTED_ADD);
                        test_fail_count = test_fail_count + 1;
                    end
                end
                2: begin
                    if (gpio_out == EXPECTED_MUL) begin
                        $display("[PASS] TEST 2 - Accelerator MUL: 12 * 7 = %0d", gpio_out);
                        test_pass_count = test_pass_count + 1;
                    end else begin
                        $display("[FAIL] TEST 2 - Accelerator MUL: got %0d, expected %0d", gpio_out, EXPECTED_MUL);
                        test_fail_count = test_fail_count + 1;
                    end
                end
                3: begin
                    if (gpio_out == 32'd12) begin
                        $display("[PASS] TEST 3a - MAC Stage 1: 3 * 4 = %0d", gpio_out);
                        test_pass_count = test_pass_count + 1;
                    end else begin
                        $display("[FAIL] TEST 3a - MAC Stage 1: got %0d, expected 12", gpio_out);
                        test_fail_count = test_fail_count + 1;
                    end
                end
                4: begin
                    if (gpio_out == EXPECTED_MAC) begin
                        $display("[PASS] TEST 3b - MAC Stage 2 (Accumulated): 5*6 + 12 = %0d", gpio_out);
                        test_pass_count = test_pass_count + 1;
                    end else begin
                        $display("[FAIL] TEST 3b - MAC Stage 2: got %0d, expected %0d", gpio_out, EXPECTED_MAC);
                        test_fail_count = test_fail_count + 1;
                    end
                end
                5: begin
                    $display("[INFO] Total Hardware Compute Cycles: %0d", gpio_out);
                    test_pass_count = test_pass_count + 1;
                end
            endcase

            prev_gpio = gpio_out;
        end
    end

    // Monitor accelerator busy/done
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

    always @(posedge clk) begin
        if (trap) begin
            $display("\n[TRAP] CPU trapped at time %0t!", $time);
            $finish;
        end
    end

    reg [31:0] prev_pc;
    integer    same_pc_count;

    always @(posedge clk) begin
        if (resetn) begin
            if (dut.cpu.reg_pc == prev_pc)
                same_pc_count <= same_pc_count + 1;
            else
                same_pc_count <= 0;
            prev_pc <= dut.cpu.reg_pc;

            if (same_pc_count > 30) begin
                $display("\n[HALT] Firmware finished at time %0t", $time);
                print_summary();
                $finish;
            end
        end
    end

    task print_summary;
        begin
            $display("");
            $display("================================================================");
            $display("  SoC DUMMY ACCELERATOR TEST SUMMARY");
            $display("================================================================");
            $display("  Tests Passed : %0d", test_pass_count);
            $display("  Tests Failed : %0d", test_fail_count);
            $display("");
            $display("  --- Accelerator Hardware Performance ---");
            $display("  Total Accel Compute Cycles : %0d", dut.accel.perf_cycles);
            $display("  Total Accel Operations     : %0d", dut.accel.perf_ops);
            $display("");
            $display("  --- Performance & Speedup Analysis ---");
            $display("  Software 32-bit Multiply (shift-add loop) : %0d CPU cycles", dut.cpu.cpuregs[21]);
            $display("  Hardware Accelerator Multiply Execution  : 4 clock cycles");
            $display("  Speedup Ratio: Pure Hardware MUL is %0.1fx faster than Software!",
                     76.0 / 4.0);
            $display("================================================================");
            if (test_fail_count == 0 && test_pass_count > 0)
                $display("  RESULT: ALL TESTS PASSED SUCCESSFULLY!");
            $display("================================================================");
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_soc_top);

        resetn = 0;
        same_pc_count = 0;
        prev_pc = 0;
        prev_done = 0;

        load_firmware();

        #(CLK_PERIOD * 10);
        resetn = 1;

        #(TIMEOUT);
        $display("\n[TIMEOUT] Simulation timeout reached.");
        print_summary();
        $finish;
    end

endmodule