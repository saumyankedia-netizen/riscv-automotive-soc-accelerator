# Project Reports Directory

This directory contains the formal engineering and academic documentation for the **RISC-V Automotive Safety SoC with an INT8 AI Accelerator** (B.Tech ECE Minor Project 1, PDEU).

## Document Index

| Report | Title | Key Contents |
|---|---|---|
| [**Report 1**](01_SoC_Accelerator_Design_Report.md) | **SoC & Dummy MAC Accelerator Architecture Design** | Memory map, MMIO registers, multi-cycle FSM pipeline, hardware vs. software $19.0\times$ speedup analysis. |
| [**Report 2**](02_RTL_to_GDSII_Implementation_Report.md) | **RTL-to-GDSII Physical Implementation & ASIC Flow** | OpenLane 2 toolchain, Sky130 standard cell library mapping, timing constraints (50 MHz), synthesis area ($168,195\,\mu\text{m}^2$). |
| [**Report 3**](03_Verification_and_Simulation_Report.md) | **Verification & Simulation Report** | Unit-level accelerator testbench (9/9 pass), full SoC testbench (5/5 pass), bug fixes, execution logs. |
| [**Report 4**](04_Automotive_Safety_and_Roadmap.md) | **Automotive Safety Context & Part 2 Roadmap** | Academic scope statement, $4 \times 4$ INT8 systolic array specifications, Time-To-Collision (TTC) inference model. |
| [**Report 5**](05_Timing_QoR_Power_and_Constraints_Report.md) | **Timing (STA), Quality of Results (QoR), Power & Constraints** | Setup slack (+4.72 ns), hold slack (+0.19 ns), total power (9.84 mW @ 50 MHz), area ($168,195\,\mu\text{m}^2$), SDC constraint analysis. |

---
*Generated for academic assessment at Pandit Deendayal Energy University (PDEU).*

