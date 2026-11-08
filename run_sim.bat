@echo off
REM =============================================================================
REM  Simulation Script for PicoRV32 SoC + Dummy MAC Accelerator
REM  Supports: Icarus Verilog (iverilog) and Synopsys VCS
REM =============================================================================

echo ================================================================
echo   PicoRV32 SoC Simulation
echo ================================================================

REM Check for available simulators
where iverilog >nul 2>&1
if %errorlevel% equ 0 (
    echo [INFO] Using Icarus Verilog
    goto :iverilog
)

where vcs >nul 2>&1
if %errorlevel% equ 0 (
    echo [INFO] Using Synopsys VCS
    goto :vcs
)

echo [ERROR] No simulator found! Install one of:
echo   - Icarus Verilog: https://bleyer.org/icarus/
echo   - Synopsys VCS (university license)
goto :end

REM =============================================================================
:iverilog
REM =============================================================================
echo.
echo --- Step 1: Compile Standalone Accelerator Test ---
iverilog -g2012 -o sim\accel_tb.vvp ^
    rtl\dummy_accelerator.v ^
    sim\tb_dummy_accelerator.sv
if %errorlevel% neq 0 (
    echo [ERROR] Compilation failed!
    goto :end
)

echo --- Step 2: Run Standalone Accelerator Test ---
cd sim
vvp accel_tb.vvp
cd ..
echo.

echo --- Step 3: Compile Full SoC Test ---
iverilog -g2012 -o sim\soc_tb.vvp ^
    rtl\picorv32.v ^
    rtl\dummy_accelerator.v ^
    rtl\mmio_decoder.v ^
    rtl\soc_top.v ^
    sim\tb_soc_top.sv
if %errorlevel% neq 0 (
    echo [ERROR] SoC compilation failed!
    goto :end
)

echo --- Step 4: Run Full SoC Test ---
cd sim
vvp soc_tb.vvp
cd ..
echo.
echo --- Waveforms saved to sim\accel_tb.vcd and sim\soc_top_tb.vcd ---
echo Open with GTKWave: gtkwave sim\accel_tb.vcd
goto :end

REM =============================================================================
:vcs
REM =============================================================================
echo.
echo --- Compile and Run with VCS ---
vcs -sverilog -full64 -debug_access+all ^
    rtl\picorv32.v ^
    rtl\dummy_accelerator.v ^
    rtl\mmio_decoder.v ^
    rtl\soc_top.v ^
    sim\tb_dummy_accelerator.sv ^
    sim\tb_soc_top.sv ^
    -o sim\simv
if %errorlevel% neq 0 (
    echo [ERROR] VCS compilation failed!
    goto :end
)
cd sim
simv
cd ..
goto :end

:end
echo.
echo Done.

