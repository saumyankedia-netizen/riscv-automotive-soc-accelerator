# Libraries & PDK Specifications Directory

This directory contains reference documentation, physical constraints, and process design kit (PDK) metadata used for the physical design of the **RISC-V Automotive Safety SoC**.

## Index of Library Files

| File | Description |
|---|---|
| [**`sky130_standard_cells.md`**](sky130_standard_cells.md) | Full architectural specifications for the **SkyWater 130nm `sky130_fd_sc_hd`** standard cell library (7-track, grid pitch, metal stack `met1`–`met5`, cell categories). |
| [**`picorv32_ip_core.md`**](picorv32_ip_core.md) | Technical reference, configuration parameters, memory bus protocol, and licensing for the **PicoRV32 RISC-V core**. |
| [**`eda_toolchain_specs.md`**](eda_toolchain_specs.md) | Tool versions and responsibilities across the OpenLane 2 tool suite (**Yosys 0.46, OpenROAD, Magic, Netgen, KLayout, Volare**). |
| [**`constraints.sdc`**](constraints.sdc) | Reference **Synopsys Design Constraints (SDC)** file defining the 50 MHz clock domain, I/O delays, load capacitances, and driving cell models. |

---
*Maintained for B.Tech ECE Minor Project 1 (PDEU).*
