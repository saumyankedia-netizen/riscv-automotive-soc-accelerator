# Report 3: Verification & Simulation Report

**Project:** Design and RTL-to-GDS Implementation of a RISC-V Based Automotive Safety SoC with an INT8 AI Accelerator  
**Student:** Saumyan Kedia  
**Institution:** Pandit Deendayal Energy University (PDEU) — B.Tech ECE (Minor Project 1)  
**Simulation Tool:** Icarus Verilog 12.0 (`-g2012`), EDA Playground, GTKWave  
**Coverage:** 100% test pass rate across unit and system testbenches  

---

## 1. Verification Strategy

The verification framework employs a bottom-up methodology:
1. **Module-Level Unit Verification (`tb_dummy_accelerator.sv`):** Exhaustive testing of the MAC arithmetic pipeline, state machine transitions, corner-case signed numbers, accumulator chaining, and performance counters.
2. **System-Level Integration Verification (`tb_soc_top.sv`):** Full SoC execution with bare-metal RISC-V machine firmware loaded into 16 KB SRAM, executing MMIO read/write instructions and validating GPIO telemetry.

---

## 2. Unit-Level Testbench Results (`tb_dummy_accelerator.sv`)

The standalone testbench exercises the accelerator across 9 comprehensive test scenarios:

| Test ID | Test Name | Stimulus Inputs | Expected Output | Observed Output | Result |
|---|---|---|---|---|---|
| **TEST 1** | Unsigned/Signed ADD | $A=12, B=7$ | $19$ (`0x00000013`) | `0x00000013` | **PASS** |
| **TEST 2** | Signed Multiplier (MUL) | $A=12, B=7$ | $84$ (`0x00000054`) | `0x00000054` | **PASS** |
| **TEST 3a**| MAC Chain — Stage 1 | $A=3, B=4, \text{Init}=0$ | $12$ | `0x0000000C` | **PASS** |
| **TEST 3b**| MAC Chain — Stage 2 | $A=5, B=6, \text{Accum}=12$| $42$ | `0x0000002A` | **PASS** |
| **TEST 4** | Signed Negative MUL | $A=-5, B=3$ | $-15$ (`0xFFFFFFF1`) | `0xFFFFFFF1` | **PASS** |
| **TEST 5** | Large 32-bit Dynamic Range | $A=1000, B=2000$ | $2,000,000$ (`0x001E8480`) | `0x001E8480` | **PASS** |
| **TEST 6** | Back-to-Back Sequential Ops | $100+200$, then $999+1$ | $300, 1000$ | $300, 1000$ | **PASS** |
| **TEST 7** | Performance Counter Audit | 8 completed operations | `perf_ops == 8` | `perf_ops = 8` | **PASS** |
| **TEST 8** | Idle State Verification | No start pulse | `busy == 0, done == 0` | `busy=0, done=0` | **PASS** |
| **TEST 9** | Boundary Protection | Write start during active | Handshake maintained | No hang / deadlock | **PASS** |

### Execution Log Summary
```
================================================================
          DUMMY ACCELERATOR STANDALONE VERIFICATION
================================================================
[TEST 1] Testing ADD (12 + 7 = 19)...                 [PASS]
[TEST 2] Testing MUL (12 * 7 = 84)...                 [PASS]
[TEST 3] Testing MAC (3*4 + 5*6 = 42)...              [PASS]
[TEST 4] Testing Signed MUL (-5 * 3 = -15)...         [PASS]
[TEST 5] Testing Large MUL (1000 * 2000 = 2000000)... [PASS]
[TEST 6] Testing Back-to-Back Operations...           [PASS]
[TEST 7] Testing Performance Counters...              [PASS]
[TEST 8] Testing Idle Status...                       [PASS]
[TEST 9] Testing Boundary / Error Handling...         [PASS]
================================================================
  ALL 9 TESTS PASSED! ACCELERATOR CORRECTLY IMPLEMENTED!
================================================================
```

---

## 3. System-Level SoC Verification Results (`tb_soc_top.sv`)

The full SoC testbench executes bare-metal RISC-V assembly instructions directly on the PicoRV32 core:

```verilog
// Firmware Execution Sequence
// 1. Initialize MMIO base addresses (x3 = 0x10000000, x4 = 0x20000000)
// 2. Perform Accelerator ADD: write operands, trigger start, poll STATUS[1]
// 3. Perform Accelerator MUL: write operands, trigger start, read RESULT_LO
// 4. Perform Accelerator MAC: 3*4=12, then 5*6+12=42
// 5. Execute Pure Software Shift-Add Multiply routine for benchmark
// 6. Write final cycle counts and status to GPIO register (0x20000000)
```

### Execution Log Summary
```
================================================================
            PicoRV32 + Dummy MAC Accelerator SoC Test
================================================================
Time 0: Reset applied
Time 200000: Reset released, CPU starting...
[TEST 1] Testing Accelerator ADD via MMIO: 12 + 7 = 19
[TEST 1] RESULT: 19 (Expected: 19) [PASS]
[TEST 2] Testing Accelerator MUL via MMIO: 12 * 7 = 84
[TEST 2] RESULT: 84 (Expected: 84) [PASS]
[TEST 3a] Testing MAC Stage 1: 3 * 4 = 12
[TEST 3a] RESULT: 12 (Expected: 12) [PASS]
[TEST 3b] Testing MAC Stage 2: 5 * 6 + 12 = 42
[TEST 3b] RESULT: 42 (Expected: 42) [PASS]
[INFO] Accelerator Total Active Compute Cycles = 17 for 4 operations
[INFO] Software 32-bit Shift-Add Loop Cycles: 76 clock cycles
[INFO] Hardware Accelerator Multiplier Cycles: 4 clock cycles
[SPEEDUP] Hardware Multiplier is 19.0x FASTER than software!
================================================================
  ALL 5 SoC INTEGRATION TESTS PASSED!
================================================================
```

---

## 4. Key Simulation Fixes Documented

During testbench development, three subtle hardware/firmware bugs were identified and corrected:

1. **Instruction Hand-Encoding Error:**
   - *Bug:* An `andi x5, x5, 2` instruction was hand-encoded as `0x00227293`, which used register `x4` (GPIO address `0x20000000`) instead of `x5` (STATUS register value). Because `0x20000000 & 2 == 0`, the firmware entered an infinite polling loop.
   - *Fix:* Re-encoded with register index `rs1 = 5` (`0x0022F293`), resolving the polling handshake.

2. **PicoRV32 Interrupt Vector Vectoring:**
   - *Bug:* With `ENABLE_IRQ = 1`, when `accel_irq_done` asserted, PicoRV32 branched to the interrupt trap handler, interrupting normal program execution.
   - *Fix:* Configured `ENABLE_IRQ = 0` and tied `irq = 32'd0` for polling MMIO mode.

3. **SystemVerilog Task Syntax:**
   - *Bug:* Older Icarus Verilog versions reject `return;` inside Verilog tasks.
   - *Fix:* Replaced early returns with explicit `timeout` flag checks.

