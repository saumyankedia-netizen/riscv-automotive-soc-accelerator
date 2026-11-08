# Project Reports Directory

This directory contains the formal engineering and academic documentation for the **RISC-V Automotive Safety SoC with an INT8 AI Accelerator** (B.Tech ECE Minor Project 1, PDEU).

---

## 1. Physical Design & ASIC Verification Reports

| Report | Title | Key Engineering Metrics |
|---|---|---|
| [**`TIMING_REPORT.md`**](TIMING_REPORT.md) | **Static Timing Analysis (STA) Report** | Clock $50\,\text{MHz}$ ($T=20\,\text{ns}$), **Setup Slack $+4.72\,\text{ns}$**, **Hold Slack $+0.19\,\text{ns}$**, $F_{\text{max}} = 65.4\,\text{MHz}$, CTS skew $84\,\text{ps}$. |
| [**`QOR_REPORT.md`**](QOR_REPORT.md) | **Quality of Results (QoR) Report** | Total silicon area **$168,195\,\mu\text{m}^2$** ($0.168\,\text{mm}^2$), **$15,660$ equivalent NAND2 gates**, $14,832$ cell instances, $45\%$ utilization, aspect ratio $1.0$. |
| [**`POWER_REPORT.md`**](POWER_REPORT.md) | **Power Analysis & PDN Report** | Total core power **$9.84\,\text{mW}$ @ $50\,\text{MHz}$**, dynamic switching $5.82\,\text{mW}$ ($59.1\%$), internal $3.41\,\text{mW}$ ($34.7\%$), leakage $0.61\,\text{mW}$ ($6.2\%$), IR-drop $< 1.8\%$. |
| [**`CONSTRAINTS_REPORT.md`**](CONSTRAINTS_REPORT.md) | **Timing Constraints (SDC) Report** | Complete SDC 2.1 clause-by-clause walkthrough: 50 MHz clock, 250 ps uncertainty, 4.0 ns I/O delays, `inv_2` driving model, 35 fF load. |

---

## 2. Architecture & Design Milestone Reports

| Report | Title | Key Contents |
|---|---|---|
| [**`01_SoC_Accelerator_Design_Report.md`**](01_SoC_Accelerator_Design_Report.md) | **SoC & Dummy MAC Accelerator Architecture** | Memory map (`0x10000000`), MMIO registers, multi-cycle FSM execution states, hardware vs. software **$19.0\times$ speedup**. |
| [**`02_RTL_to_GDSII_Implementation_Report.md`**](02_RTL_to_GDSII_Implementation_Report.md) | **RTL-to-GDSII Physical Flow** | OpenLane 2 toolchain, SkyWater 130nm mapping, floorplan, power grid, and automated GitHub Actions CI/CD runner. |
| [**`03_Verification_and_Simulation_Report.md`**](03_Verification_and_Simulation_Report.md) | **Verification & Simulation Audit** | Standalone testbench (9/9 pass), full SoC testbench (5/5 pass), bug fixes, execution logs. |
| [**`04_Automotive_Safety_and_Roadmap.md`**](04_Automotive_Safety_and_Roadmap.md) | **Safety Context & Part 2 Roadmap** | Academic scope statement (non-ASIL-D / academic prototype), $4 \times 4$ INT8 systolic array specifications, and Time-To-Collision (TTC) inference model. |
| [**`05_Timing_QoR_Power_and_Constraints_Report.md`**](05_Timing_QoR_Power_and_Constraints_Report.md) | **Consolidated Physical Summary Report** | Combined multi-domain summary of Timing, QoR, Power, and SDC constraints. |

---
*Maintained for academic evaluation at Pandit Deendayal Energy University (PDEU).*
