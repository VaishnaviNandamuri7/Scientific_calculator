## Board_Top on the Nexys 4 DDR / Nexys A7-100T (xc7a100tcsg324-1)
## Pins taken from Digilent's Nexys-4-DDR-Master.xdc

## 100 MHz clock
set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports CLK100MHZ]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports CLK100MHZ]

## 1 MHz CPU clock made by the divider in Board_Top (100 MHz / 100)
create_generated_clock -name cpu_clk -source [get_ports CLK100MHZ] -divide_by 100 [get_pins clk_slow_reg/Q]

## CPU RESET button (0 when pressed)
set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports CPU_RESETN]

## USB-UART
set_property -dict { PACKAGE_PIN C4  IOSTANDARD LVCMOS33 } [get_ports UART_TXD_IN]
set_property -dict { PACKAGE_PIN D4  IOSTANDARD LVCMOS33 } [get_ports UART_RXD_OUT]

## Status LEDs: 0 loading, 1 running, 2 halted, 3 sending
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports {LED[0]}]
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports {LED[1]}]
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports {LED[2]}]
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports {LED[3]}]

## Configuration bank voltage (removes a DRC warning)
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
