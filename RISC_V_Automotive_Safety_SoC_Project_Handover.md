# Project Handover Brief --- RISC-V Automotive Safety SoC with INT8 AI Accelerator

**Prepared:** 5 November 2026\
**Purpose:** Context file to share with other AI models or
collaborators.

## 1. Project identity

**Working title:** Design and RTL-to-GDS Implementation of a RISC-V
Based Automotive Safety SoC with an INT8 AI Accelerator.

**Academic context:** B.Tech Electronics and Communication Engineering
(ECE), PDEU. This is an academic prototype, not a production automotive
controller.

**Goal:** Design and verify a RISC-V-based SoC integrating a lightweight
INT8 AI accelerator and basic automotive-safety-oriented logic. The
planned workflow extends from RTL design and simulation through
synthesis and physical-design stages, and GDSII if the required
technology collateral and tools are available.

**Safety caveat:** Do not claim ISO 26262 compliance, production
automotive qualification, or silicon-proven safety without the required
evidence. Discuss automotive safety standards as context only.

## 2. Timeline and phases

  -----------------------------------------------------------------------
  Phase                   Planned period          Main focus
  ----------------------- ----------------------- -----------------------
  Part 1 / Minor project  October--December 2026  PicoRV32
                                                  study/configuration,
                                                  SoC foundation, memory
                                                  map/MMIO, simple dummy
                                                  accelerator, RTL
                                                  simulation.

  Part 2 / Major project  January--April 2027     MATLAB reference model,
                                                  INT8 quantization and
                                                  accelerator,
                                                  safety-oriented logic,
                                                  integration,
                                                  verification, synthesis
                                                  and physical design.
  -----------------------------------------------------------------------

These are planned dates, not proof of completed implementation. Always
distinguish planned, in-progress, implemented, and verified tasks.

### Part 1 --- SoC foundation

1.  Study PicoRV32 architecture, configuration parameters, and
    interfaces.
2.  Understand the native memory interface and valid/ready handshaking.
3.  Define a memory map and address decoder.
4.  Integrate instruction/data memory or SRAM models as appropriate.
5.  Add memory-mapped I/O (MMIO).
6.  Define an accelerator command/control interface.
7.  Decide whether the initial accelerator uses MMIO, PCPI, or both.
8.  Create a simple dummy accelerator and testbench.
9.  Write firmware/software tests.
10. Run simulation and initial synthesis where tools are available.

### Part 2 --- AI accelerator and safety-oriented functionality

1.  Develop a MATLAB reference model for the selected workload.
2.  Define INT8 quantization, scaling, zero-point, rounding, and
    saturation.
3.  Design an INT8 multiply-accumulate (MAC) processing element.
4.  Explore a small PE array, initially potentially 4×4, subject to
    resources and schedule.
5.  Define input, weight, and output buffering/data movement.
6.  Integrate the accelerator with the RISC-V SoC.
7.  Develop an educational automotive-safety use case, such as
    obstacle/motion processing and time-to-collision (TTC) or
    collision-warning logic.
8.  Verify against the MATLAB/reference model.
9.  Run synthesis and physical-design steps subject to available
    libraries, technology files, constraints, licenses, and time.

### RTL-to-GDS stages to investigate

-   RTL elaboration and linting
-   Functional simulation and regression
-   Synthesis
-   SDC/clock and I/O constraints
-   Floorplanning
-   Placement
-   Clock-tree synthesis (CTS)
-   Routing
-   Parasitic extraction
-   Static timing analysis (STA)
-   Power analysis and, if supported, IR-drop analysis
-   DRC/LVS and GDSII export, if PDK, decks, and licenses are available

**Feasibility caveat:** Full signoff/GDSII depends on the PDK,
standard-cell libraries, timing/power models, physical verification
decks, EDA access, and project complexity. Be explicit about
limitations.

## 3. Processor and SoC direction

The proposed processor is **PicoRV32**, a compact open-source RISC-V
core from YosysHQ.

Relevant capabilities to investigate: - Native memory interface -
Optional PCPI (Pico Co-Processor Interface) - Optional IRQ support -
Configurable core options

The native memory interface is relevant for instruction/data access.
MMIO is a straightforward initial approach for accelerator configuration
and status. PCPI is an option for custom-instruction/coprocessor
integration if required by the supervisor.

Official repository/documentation: https://github.com/YosysHQ/picorv32

The exact memory map, clock frequency, bus topology, SRAM size, and
accelerator base address are not finalized. Treat these as design
decisions.

## 4. Dummy accelerator --- immediate milestone

The supervisor has asked for a **dummy accelerator**. Recommended first
milestone: a small synthesizable arithmetic coprocessor demonstrating a
real CPU-to-accelerator control/data path, before building the full INT8
AI accelerator.

### Suggested functionality

-   Two inputs: `operand_a`, `operand_b`
-   Operation selector: ADD and optionally MULTIPLY
-   `start` control
-   `busy` and `done` status
-   Result register/output
-   Optional interrupt request

A multi-cycle FSM demonstrates sequencing and a visible busy/done
handshake. A combinational adder alone may be too trivial.

### Suggested module breakdown

-   `soc_top.v` --- top-level integration
-   `dummy_accelerator.v` --- arithmetic operation and control FSM
-   `mmio_decoder.v` --- address decode and register access
-   `tb_dummy_accelerator.sv` --- testbench

These are suggested names, not confirmed existing files.

### Example MMIO register map

Offsets are relative to a base address that still needs to be selected.

    Offset Register    Example purpose
  -------- ----------- ------------------
    `0x00` CONTROL     Write start bit
    `0x04` STATUS      Read busy/done
    `0x08` OPERAND_A   First operand
    `0x0C` OPERAND_B   Second operand
    `0x10` RESULT      Read result
    `0x14` OPERATION   Select operation

### Basic test scenario

1.  Reset the SoC and accelerator.
2.  Write `12` to `OPERAND_A`, `7` to `OPERAND_B`.
3.  Select ADD and write the start bit.
4.  Confirm `busy` asserts during processing.
5.  Confirm `done` asserts on completion.
6.  Read the result and check it equals `19`.
7.  Check reset behavior and status-flag clearing.

Additional tests: back-to-back operations, invalid opcode, reset while
idle/busy, start while busy, operand boundary values, and result-read
timing.

### MMIO versus PCPI

**MMIO-first recommendation:** Use MMIO for the first dummy accelerator.
It is straightforward to inspect in simulation and demonstrates
register-based control/status.

**PCPI option:** If the supervisor specifically wants a custom RISC-V
instruction, investigate PicoRV32 PCPI. Relevant signals include
`pcpi_valid`, `pcpi_insn`, `pcpi_rs1`, `pcpi_rs2`, `pcpi_wr`, `pcpi_rd`,
`pcpi_wait`, and `pcpi_ready`.

PCPI is optional and must be enabled/configured appropriately. A PCPI
implementation must decode the intended instruction encoding and
correctly implement wait/ready/writeback. Do not invent an instruction
encoding without documenting it.

Recommended staged strategy: **MMIO dummy accelerator first; PCPI custom
instruction later only if it serves a clear project requirement.**

## 5. Research papers and references identified

These papers were identified as potentially relevant. Verify metadata
and read the full text through IEEE Xplore or the publisher before
relying on detailed claims. No single identified paper covers the entire
combination of PicoRV32, INT8 AI acceleration, automotive safety, and
RTL-to-GDS.

### A. Closest match to the immediate PicoRV32 dummy/custom accelerator milestone

**"Design and Implementation of a Custom Multiply Accumulate Instruction
in an Open-Source RISC-V Processor Core"**

-   Authors listed in search results: S. Hemajothi, S. Jalaja, M.
    Kishore, and S. Gowtham Kumar
-   Conference: 2026 9th International Conference on Circuit, Power &
    Computing Technologies (ICCPCT)
-   DOI: `10.1109/ICCPCT70290.2026.11654754`
-   IEEE Xplore: https://ieeexplore.ieee.org/abstract/document/11654754/

Search-result abstract describes a custom MAC instruction in PicoRV32
using PCPI, opcode decoding and operand transfer through PCPI, Verilog
implementation, functional simulation, and FPGA synthesis.

Use it to study PCPI integration and the MAC datapath, then compare
those ideas with the chosen dummy accelerator. Do not assume its RTL can
be copied directly or that its design matches this project's
requirements. It is the closest immediate match for a PCPI-based custom
accelerator, not a complete automotive SoC reference.

### B. INT8 / CNN accelerator support

**"An FPGA-Based Secure and Privacy-Aware RISC-V SoC with a CNN
Accelerator for Edge AI"**

-   IEEE, 2026
-   DOI: `10.1109/VLSID68508.2026.00016`

Search-result abstract describes a RISC-V SoC with a quantized CNN
accelerator and parallel 8-bit MAC operations. Review the full paper for
accelerator architecture, dataflow, quantization, buffering,
CPU/accelerator interface, and measured performance.

### C. Automotive safety context

**"RISC-V Functional Safety for Autonomous Automotive Systems: An
Analytical Framework and Research Roadmap for ML-Assisted
Certification"**

-   Authors listed in search results: Nick Andreasyan, Mikhail Struve,
    Alexey Popov, Maksim Nikolaev, and Vadim Vashkelis
-   arXiv: https://arxiv.org/abs/2604.17391

Search-result abstract discusses automotive RISC-V safety context,
including ISO 26262, ISO 21448/SOTIF, lockstep, safety islands,
diagnostic coverage, and certification. Use as background; do not claim
the student prototype is certified or compliant based on this paper.

### D. Other supporting papers identified

1.  "A Reconfigurable Convolutional Neural Network-Accelerated
    Coprocessor Based on RISC-V Instruction Set" ---
    *Electronics*, 2020. DOI: `10.3390/electronics9061005`.
2.  "Design of SoC System for Convolution Acceleration Based on RISC-V
    Processor" --- *Computer Engineering*, 2021. DOI:
    `10.19678/j.issn.1000-3428.0057835`.
3.  "FPGA-Based Reconfigurable SoCs for Safety-Critical AI Inference: A
    Systematic Literature Review" --- *Electronics*, June 2026.
4.  "Open-Source Ibex RISC-V Based ISO 26262-Compliant Dual-Core
    Lockstep SoC..." --- 2026 search result. It uses Ibex rather than
    PicoRV32, so treat it as a contrasting architecture rather than a
    direct match.

## 6. Existing project artifacts

Files created earlier in the project conversation:

1.  **Part 1 presentation:**
    `Automotive_Safety_SoC_Minor_Project_Part1.pptx`\
    Previously shared path:
    `sandbox:/mnt/data/Automotive_Safety_SoC_Minor_Project_Part1.pptx`\
    The 11-slide deck covers title, introduction, motivation, literature
    review, objectives, methodology, Part 1 architecture, work/progress,
    timeline, conclusion, and references. It distinguishes
    planning/specification from implementation/testing.

2.  **Detailed tracker:**
    `RISC_V_Automotive_Safety_SoC_Detailed_Tracker.xlsx`\
    Previously shared path:
    `sandbox:/mnt/data/RISC_V_Automotive_Safety_SoC_Detailed_Tracker.xlsx`\
    Sheets: Dashboard, Part 1 - SoC, Part 2 - AI, RTL-to-GDS, Timeline,
    and Read Me. It has 103 task rows: 34 Part 1, 37 Part 2 AI, and 32
    RTL-to-GDS. It includes status dropdowns, conditional formatting,
    target dates, priorities, owners, actual completion dates, and
    notes/evidence fields. It is a planning baseline, not proof that
    tasks are complete.

## 7. Tools and verification environment

Tools mentioned or planned: - Verilog/SystemVerilog for RTL and
testbenches - PicoRV32 as proposed CPU - MATLAB for the reference
algorithm/model - Synopsys VCS for simulation/verification, subject to
access - University synthesis and physical-design tools (exact toolchain
and PDK not yet confirmed)

Ask what licenses, versions, libraries, and PDK collateral are actually
available. Do not assume them.

## 8. Open decisions / information still needed

Not finalized in the known project context: - Exact SoC memory map and
accelerator base address - Exact PicoRV32 configuration and enabled
options - MMIO only, PCPI only, or staged combination - Whether the
supervisor explicitly requires custom instructions - Dummy accelerator
operation set and latency - Final INT8 workload/model - Quantization
scheme and numerical behavior - PE array dimensions and memory/buffer
architecture - Safety-use-case input signals and algorithm - Clock
frequency, reset strategy, and bus timing - Available EDA tools, PDK,
standard-cell library, timing models, and physical verification decks -
Final deliverables and acceptance criteria

Do not silently choose these. Propose options, explain trade-offs, and
label assumptions.

## 9. Guidance for another AI model

1.  Preserve the scope and timeline unless the student changes them.
2.  Give technically detailed, step-by-step guidance appropriate for a
    B.Tech ECE project.
3.  Separate confirmed facts from assumptions and recommendations.
4.  Do not claim code has been simulated, synthesized, or verified
    unless an actual run/result is supplied.
5.  When writing RTL, provide synthesizable code, explain
    modules/interfaces, and include a testbench with expected results.
6.  Keep the first dummy accelerator small and demonstrable. Do not jump
    to a large CNN before the CPU/SoC interface works.
7.  Explain MMIO and PCPI trade-offs. Ask whether the supervisor
    requires PCPI before committing to a custom instruction.
8.  Use MATLAB as a golden/reference model for the later INT8 datapath
    and define fixed-point behavior precisely.
9.  Treat automotive safety as a prototype/research motivation. Do not
    claim ISO 26262 certification or production readiness.
10. For literature reviews, provide verifiable title, authors, venue,
    year, DOI/publisher link, and explain which subsystem each paper
    supports.
11. Be honest about tool/PDK dependencies and distinguish synthesis from
    physical signoff.
12. Prefer incremental milestones with measurable acceptance criteria
    and tests.

### Best immediate next step

Inspect the full text of the PicoRV32 custom MAC/PCPI paper, then
translate relevant concepts into a small dummy accelerator specification
and implementation plan. Before writing RTL, establish whether the
supervisor expects an MMIO peripheral or a PCPI custom-instruction
coprocessor.

## 10. Short prompt to paste into another model

I am a B.Tech ECE student at PDEU working on **"Design and RTL-to-GDS
Implementation of a RISC-V Based Automotive Safety SoC with an INT8 AI
Accelerator."** Part 1 (Oct--Dec 2026) focuses on
understanding/configuring PicoRV32, building the SoC foundation, memory
map and MMIO, and demonstrating a simple dummy accelerator. Part 2
(Jan--Apr 2027) focuses on a MATLAB reference model, INT8 quantization
and MAC accelerator (possibly a small 4×4 PE array),
automotive-safety-oriented processing such as TTC/collision warning,
integration, verification, synthesis, and physical-design steps where
the available PDK/tools permit. My supervisor has asked me to build a
dummy accelerator first. MMIO is the recommended easiest starting point;
PicoRV32 PCPI is an option if a custom RISC-V instruction is required.
The closest identified paper for that milestone is "Design and
Implementation of a Custom Multiply Accumulate Instruction in an
Open-Source RISC-V Processor Core" (DOI:
10.1109/ICCPCT70290.2026.11654754). Please guide me incrementally,
distinguish assumptions from confirmed facts, and do not claim
implementation or verification has happened unless evidence is supplied.
