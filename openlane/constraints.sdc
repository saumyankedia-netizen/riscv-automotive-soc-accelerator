#=============================================================================
# Synopsys Design Constraints (SDC) for soc_core
# Target: 50 MHz (20.0 ns period) on Sky130
#=============================================================================

set_units -time ns -resistance kOhm -capacitance pF -voltage V -current mA

# Clock definition (50 MHz = 20 ns period)
create_clock -name clk -period 20.000 [get_ports clk]

# Clock uncertainty and transition
set_clock_uncertainty 0.25 [get_clocks clk]
set_clock_transition 0.15 [get_clocks clk]

# Input delays (assumes 20% of cycle external delay)
set_input_delay -clock clk 4.0 [all_inputs]
set_input_delay -clock clk 0.0 [get_ports clk]

# Output delays (assumes 20% of cycle external delay)
set_output_delay -clock clk 4.0 [all_outputs]

# Driving cell and output load for Sky130
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 [all_inputs]
set_load 0.035 [all_outputs]

