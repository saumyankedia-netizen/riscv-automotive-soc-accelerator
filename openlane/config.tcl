# OpenLane Configuration for soc_core (PicoRV32 + Dummy MAC Accelerator)
set ::env(DESIGN_NAME) "soc_core"

set ::env(VERILOG_FILES) [glob $::env(DESIGN_DIR)/../rtl/picorv32.v \
                               $::env(DESIGN_DIR)/../rtl/dummy_accelerator.v \
                               $::env(DESIGN_DIR)/../rtl/mmio_decoder.v \
                               $::env(DESIGN_DIR)/../rtl/soc_core.v]

set ::env(CLOCK_PORT) "clk"
set ::env(CLOCK_PERIOD) "20.0"
set ::env(CLOCK_NET) "clk"

set ::env(FP_CORE_UTIL) 45
set ::env(FP_ASPECT_RATIO) 1.0
set ::env(PL_TARGET_DENSITY) 0.50

set ::env(SYNTH_STRATEGY) "AREA 0"

set ::env(RUN_KLAYOUT_XOR) 0
set ::env(RUN_KLAYOUT_DRC) 0
set ::env(RUN_MAGIC_DRC) 1
set ::env(RUN_LVS) 0

