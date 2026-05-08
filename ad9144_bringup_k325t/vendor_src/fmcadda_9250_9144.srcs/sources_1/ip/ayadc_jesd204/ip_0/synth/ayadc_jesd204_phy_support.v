//----------------------------------------------------------------------------
// Title : Support Level Module
// Project : JESD204 PHY
//----------------------------------------------------------------------------
// File : jesd204_phy_support.v
//----------------------------------------------------------------------------
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//----------------------------------------------------------------------------

`timescale 1ns / 1ps

(* DowngradeIPIdentifiedWarnings = "yes" *)
module ayadc_jesd204_phy_support (
  // GT Reset Done Outputs
  output         gt0_txresetdone_out,
  output         gt0_rxresetdone_out,

  output         gt0_cplllock_out,

  // RX Margin Analysis Ports
  output         gt0_eyescandataerror_out,
  input          gt0_eyescantrigger_in,
  input          gt0_eyescanreset_in,

  // TX Pattern Checker ports
  input          gt0_txprbsforceerr_in,

  // TX Initialization
  input          gt0_txpcsreset_in,
  input          gt0_txpmareset_in,

  // TX Buffer Ports
  output [1:0]   gt0_txbufstatus_out,

  // Rx CDR Ports
  input          gt0_rxcdrhold_in,

  // RX Pattern Checker ports
  output         gt0_rxprbserr_out,
  input  [2:0]   gt0_rxprbssel_in,
  input          gt0_rxprbscntreset_in,

  // RX Buffer Bypass Ports
  input          gt0_rxbufreset_in,
  output [2:0]   gt0_rxbufstatus_out,
  output [2:0]   gt0_rxstatus_out,

  // RX Byte and Word Alignment Ports
  output         gt0_rxbyteisaligned_out,
  output         gt0_rxbyterealign_out,
  output         gt0_rxcommadet_out,

  // Digital Monitor Ports
  output [7:0]   gt0_dmonitorout_out,


  // RX Initialization and Reset Ports
  input          gt0_rxpcsreset_in,
  input          gt0_rxpmareset_in,

  // Receive Ports - RX Equalizer Ports
  input          gt0_rxlpmen_in,
  input          gt0_rxdfelpmreset_in,
  output [6:0]   gt0_rxmonitorout_out,
  input  [1:0]   gt0_rxmonitorsel_in,

  // Loopback
  input  [2:0]   gt0_loopback_in,

  // Power Down Ports
  input  [1:0]   gt0_rxpd_in,
  input  [1:0]   gt0_txpd_in,

  // GT Tx Control
  input  [4:0]   gt0_txpostcursor_in,
  input  [4:0]   gt0_txprecursor_in,
  input  [3:0]   gt0_txdiffctrl_in,
  input          gt0_txpolarity_in,
  input          gt0_txinhibit_in,

  // Rx Polarity Port
  input          gt0_rxpolarity_in,

   // DRP Ports
  input  [8:0]   gt0_drpaddr,
  input  [15:0]  gt0_drpdi,
  input          gt0_drpen,
  input          gt0_drpwe,
  output [15:0]  gt0_drpdo,
  output         gt0_drprdy,

  // GT Reset Done Outputs
  output         gt1_txresetdone_out,
  output         gt1_rxresetdone_out,

  output         gt1_cplllock_out,

  // RX Margin Analysis Ports
  output         gt1_eyescandataerror_out,
  input          gt1_eyescantrigger_in,
  input          gt1_eyescanreset_in,

  // TX Pattern Checker ports
  input          gt1_txprbsforceerr_in,

  // TX Initialization
  input          gt1_txpcsreset_in,
  input          gt1_txpmareset_in,

  // TX Buffer Ports
  output [1:0]   gt1_txbufstatus_out,

  // Rx CDR Ports
  input          gt1_rxcdrhold_in,

  // RX Pattern Checker ports
  output         gt1_rxprbserr_out,
  input  [2:0]   gt1_rxprbssel_in,
  input          gt1_rxprbscntreset_in,

  // RX Buffer Bypass Ports
  input          gt1_rxbufreset_in,
  output [2:0]   gt1_rxbufstatus_out,
  output [2:0]   gt1_rxstatus_out,

  // RX Byte and Word Alignment Ports
  output         gt1_rxbyteisaligned_out,
  output         gt1_rxbyterealign_out,
  output         gt1_rxcommadet_out,

  // Digital Monitor Ports
  output [7:0]   gt1_dmonitorout_out,


  // RX Initialization and Reset Ports
  input          gt1_rxpcsreset_in,
  input          gt1_rxpmareset_in,

  // Receive Ports - RX Equalizer Ports
  input          gt1_rxlpmen_in,
  input          gt1_rxdfelpmreset_in,
  output [6:0]   gt1_rxmonitorout_out,
  input  [1:0]   gt1_rxmonitorsel_in,

  // Loopback
  input  [2:0]   gt1_loopback_in,

  // Power Down Ports
  input  [1:0]   gt1_rxpd_in,
  input  [1:0]   gt1_txpd_in,

  // GT Tx Control
  input  [4:0]   gt1_txpostcursor_in,
  input  [4:0]   gt1_txprecursor_in,
  input  [3:0]   gt1_txdiffctrl_in,
  input          gt1_txpolarity_in,
  input          gt1_txinhibit_in,

  // Rx Polarity Port
  input          gt1_rxpolarity_in,

   // DRP Ports
  input  [8:0]   gt1_drpaddr,
  input  [15:0]  gt1_drpdi,
  input          gt1_drpen,
  input          gt1_drpwe,
  output [15:0]  gt1_drpdo,
  output         gt1_drprdy,

  // GT Reset Done Outputs
  output         gt2_txresetdone_out,
  output         gt2_rxresetdone_out,

  output         gt2_cplllock_out,

  // RX Margin Analysis Ports
  output         gt2_eyescandataerror_out,
  input          gt2_eyescantrigger_in,
  input          gt2_eyescanreset_in,

  // TX Pattern Checker ports
  input          gt2_txprbsforceerr_in,

  // TX Initialization
  input          gt2_txpcsreset_in,
  input          gt2_txpmareset_in,

  // TX Buffer Ports
  output [1:0]   gt2_txbufstatus_out,

  // Rx CDR Ports
  input          gt2_rxcdrhold_in,

  // RX Pattern Checker ports
  output         gt2_rxprbserr_out,
  input  [2:0]   gt2_rxprbssel_in,
  input          gt2_rxprbscntreset_in,

  // RX Buffer Bypass Ports
  input          gt2_rxbufreset_in,
  output [2:0]   gt2_rxbufstatus_out,
  output [2:0]   gt2_rxstatus_out,

  // RX Byte and Word Alignment Ports
  output         gt2_rxbyteisaligned_out,
  output         gt2_rxbyterealign_out,
  output         gt2_rxcommadet_out,

  // Digital Monitor Ports
  output [7:0]   gt2_dmonitorout_out,


  // RX Initialization and Reset Ports
  input          gt2_rxpcsreset_in,
  input          gt2_rxpmareset_in,

  // Receive Ports - RX Equalizer Ports
  input          gt2_rxlpmen_in,
  input          gt2_rxdfelpmreset_in,
  output [6:0]   gt2_rxmonitorout_out,
  input  [1:0]   gt2_rxmonitorsel_in,

  // Loopback
  input  [2:0]   gt2_loopback_in,

  // Power Down Ports
  input  [1:0]   gt2_rxpd_in,
  input  [1:0]   gt2_txpd_in,

  // GT Tx Control
  input  [4:0]   gt2_txpostcursor_in,
  input  [4:0]   gt2_txprecursor_in,
  input  [3:0]   gt2_txdiffctrl_in,
  input          gt2_txpolarity_in,
  input          gt2_txinhibit_in,

  // Rx Polarity Port
  input          gt2_rxpolarity_in,

   // DRP Ports
  input  [8:0]   gt2_drpaddr,
  input  [15:0]  gt2_drpdi,
  input          gt2_drpen,
  input          gt2_drpwe,
  output [15:0]  gt2_drpdo,
  output         gt2_drprdy,

  // GT Reset Done Outputs
  output         gt3_txresetdone_out,
  output         gt3_rxresetdone_out,

  output         gt3_cplllock_out,

  // RX Margin Analysis Ports
  output         gt3_eyescandataerror_out,
  input          gt3_eyescantrigger_in,
  input          gt3_eyescanreset_in,

  // TX Pattern Checker ports
  input          gt3_txprbsforceerr_in,

  // TX Initialization
  input          gt3_txpcsreset_in,
  input          gt3_txpmareset_in,

  // TX Buffer Ports
  output [1:0]   gt3_txbufstatus_out,

  // Rx CDR Ports
  input          gt3_rxcdrhold_in,

  // RX Pattern Checker ports
  output         gt3_rxprbserr_out,
  input  [2:0]   gt3_rxprbssel_in,
  input          gt3_rxprbscntreset_in,

  // RX Buffer Bypass Ports
  input          gt3_rxbufreset_in,
  output [2:0]   gt3_rxbufstatus_out,
  output [2:0]   gt3_rxstatus_out,

  // RX Byte and Word Alignment Ports
  output         gt3_rxbyteisaligned_out,
  output         gt3_rxbyterealign_out,
  output         gt3_rxcommadet_out,

  // Digital Monitor Ports
  output [7:0]   gt3_dmonitorout_out,


  // RX Initialization and Reset Ports
  input          gt3_rxpcsreset_in,
  input          gt3_rxpmareset_in,

  // Receive Ports - RX Equalizer Ports
  input          gt3_rxlpmen_in,
  input          gt3_rxdfelpmreset_in,
  output [6:0]   gt3_rxmonitorout_out,
  input  [1:0]   gt3_rxmonitorsel_in,

  // Loopback
  input  [2:0]   gt3_loopback_in,

  // Power Down Ports
  input  [1:0]   gt3_rxpd_in,
  input  [1:0]   gt3_txpd_in,

  // GT Tx Control
  input  [4:0]   gt3_txpostcursor_in,
  input  [4:0]   gt3_txprecursor_in,
  input  [3:0]   gt3_txdiffctrl_in,
  input          gt3_txpolarity_in,
  input          gt3_txinhibit_in,

  // Rx Polarity Port
  input          gt3_rxpolarity_in,

   // DRP Ports
  input  [8:0]   gt3_drpaddr,
  input  [15:0]  gt3_drpdi,
  input          gt3_drpen,
  input          gt3_drpwe,
  output [15:0]  gt3_drpdo,
  output         gt3_drprdy,

  // System Reset Inputs for each direction
  input          tx_sys_reset,
  input          rx_sys_reset,
  
  // Reset Inputs for each direction
  input          tx_reset_gt,
  input          rx_reset_gt,

  // Reset Done for each direction
  output         tx_reset_done,
  output         rx_reset_done,

  input          cpll_refclk,

  input          rxencommaalign,

  // Clocks
  input          tx_core_clk,
  output         txoutclk,
  input          rx_core_clk,
  output         rxoutclk,
  input          drpclk,
  
  
  // PRBS mode
  input  [2:0]   gt_prbssel,

  // Tx Ports
  // Lane 0
  input  [31:0]  gt0_txdata,
  input  [3:0]   gt0_txcharisk,

  // Lane 1
  input  [31:0]  gt1_txdata,
  input  [3:0]   gt1_txcharisk,

  // Lane 2
  input  [31:0]  gt2_txdata,
  input  [3:0]   gt2_txcharisk,

  // Lane 3
  input  [31:0]  gt3_txdata,
  input  [3:0]   gt3_txcharisk,

  // Rx Ports
  // Lane 0
  output [31:0]  gt0_rxdata,
  output [3:0]   gt0_rxcharisk,
  output [3:0]   gt0_rxdisperr,
  output [3:0]   gt0_rxnotintable,

  // Lane 1
  output [31:0]  gt1_rxdata,
  output [3:0]   gt1_rxcharisk,
  output [3:0]   gt1_rxdisperr,
  output [3:0]   gt1_rxnotintable,

  // Lane 2
  output [31:0]  gt2_rxdata,
  output [3:0]   gt2_rxcharisk,
  output [3:0]   gt2_rxdisperr,
  output [3:0]   gt2_rxnotintable,

  // Lane 3
  output [31:0]  gt3_rxdata,
  output [3:0]   gt3_rxcharisk,
  output [3:0]   gt3_rxdisperr,
  output [3:0]   gt3_rxnotintable,

  // Serial ports
  input  [3:0]   rxn_in,
  input  [3:0]   rxp_in,
  output [3:0]   txn_out,
  output [3:0]   txp_out
);


//*******************************************
// Wire Declarations
//*******************************************

//*******************************************
// JESD204 PHY Core
//*******************************************
ayadc_jesd204_phy_block jesd204_phy_block_i
 (
  // GT Reset Done Outputs
  .gt0_txresetdone_out         (gt0_txresetdone_out),
  .gt0_rxresetdone_out         (gt0_rxresetdone_out),

  .gt0_cplllock_out            (gt0_cplllock_out),

  // Loopback
  .gt0_loopback_in             (gt0_loopback_in),

  // Power Down Ports
  .gt0_rxpd_in                 (gt0_rxpd_in),
  .gt0_txpd_in                 (gt0_txpd_in),

  // GT Tx Control
  .gt0_txpostcursor_in         (gt0_txpostcursor_in),
  .gt0_txprecursor_in          (gt0_txprecursor_in),
  .gt0_txdiffctrl_in           (gt0_txdiffctrl_in),
  .gt0_txpolarity_in           (gt0_txpolarity_in),
  .gt0_txinhibit_in            (gt0_txinhibit_in),

  // Rx Polarity Port
  .gt0_rxpolarity_in           (gt0_rxpolarity_in),

  // DRP Ports
  .gt0_drpaddr                 (gt0_drpaddr),
  .gt0_drpdi                   (gt0_drpdi),
  .gt0_drpen                   (gt0_drpen),
  .gt0_drpwe                   (gt0_drpwe),
  .gt0_drpdo                   (gt0_drpdo),
  .gt0_drprdy                  (gt0_drprdy),

  // RX Margin Analysis Ports
  .gt0_eyescandataerror_out    (gt0_eyescandataerror_out),
  .gt0_eyescantrigger_in       (gt0_eyescantrigger_in),
  .gt0_eyescanreset_in         (gt0_eyescanreset_in),

  // TX Pattern Checker ports
  .gt0_txprbsforceerr_in       (gt0_txprbsforceerr_in),

  // TX Initialization
  .gt0_txpcsreset_in           (gt0_txpcsreset_in),
  .gt0_txpmareset_in           (gt0_txpmareset_in),

  // TX Buffer Ports
  .gt0_txbufstatus_out         (gt0_txbufstatus_out),

  // Rx CDR Ports
  .gt0_rxcdrhold_in            (gt0_rxcdrhold_in),

  // Receive Ports - Pattern Checker ports
  .gt0_rxprbserr_out           (gt0_rxprbserr_out),
  .gt0_rxprbssel_in            (gt0_rxprbssel_in),
  .gt0_rxprbscntreset_in       (gt0_rxprbscntreset_in),

  // RX Buffer Bypass Ports
  .gt0_rxbufreset_in           (gt0_rxbufreset_in),
  .gt0_rxbufstatus_out         (gt0_rxbufstatus_out),
  .gt0_rxstatus_out            (gt0_rxstatus_out),

  // RX Byte and Word Alignment Ports
  .gt0_rxbyteisaligned_out     (gt0_rxbyteisaligned_out),
  .gt0_rxbyterealign_out       (gt0_rxbyterealign_out),
  .gt0_rxcommadet_out          (gt0_rxcommadet_out),

  // Digital Monitor Ports
  .gt0_dmonitorout_out         (gt0_dmonitorout_out),


  // RX Initialization and Reset Ports
  .gt0_rxpcsreset_in           (gt0_rxpcsreset_in),
  .gt0_rxpmareset_in           (gt0_rxpmareset_in),

  // Receive Ports - RX Equalizer Ports
  .gt0_rxlpmen_in              (gt0_rxlpmen_in),
  .gt0_rxdfelpmreset_in        (gt0_rxdfelpmreset_in),
  .gt0_rxmonitorout_out        (gt0_rxmonitorout_out),
  .gt0_rxmonitorsel_in         (gt0_rxmonitorsel_in),

  // GT Reset Done Outputs
  .gt1_txresetdone_out         (gt1_txresetdone_out),
  .gt1_rxresetdone_out         (gt1_rxresetdone_out),

  .gt1_cplllock_out            (gt1_cplllock_out),

  // Loopback
  .gt1_loopback_in             (gt1_loopback_in),

  // Power Down Ports
  .gt1_rxpd_in                 (gt1_rxpd_in),
  .gt1_txpd_in                 (gt1_txpd_in),

  // GT Tx Control
  .gt1_txpostcursor_in         (gt1_txpostcursor_in),
  .gt1_txprecursor_in          (gt1_txprecursor_in),
  .gt1_txdiffctrl_in           (gt1_txdiffctrl_in),
  .gt1_txpolarity_in           (gt1_txpolarity_in),
  .gt1_txinhibit_in            (gt1_txinhibit_in),

  // Rx Polarity Port
  .gt1_rxpolarity_in           (gt1_rxpolarity_in),

  // DRP Ports
  .gt1_drpaddr                 (gt1_drpaddr),
  .gt1_drpdi                   (gt1_drpdi),
  .gt1_drpen                   (gt1_drpen),
  .gt1_drpwe                   (gt1_drpwe),
  .gt1_drpdo                   (gt1_drpdo),
  .gt1_drprdy                  (gt1_drprdy),

  // RX Margin Analysis Ports
  .gt1_eyescandataerror_out    (gt1_eyescandataerror_out),
  .gt1_eyescantrigger_in       (gt1_eyescantrigger_in),
  .gt1_eyescanreset_in         (gt1_eyescanreset_in),

  // TX Pattern Checker ports
  .gt1_txprbsforceerr_in       (gt1_txprbsforceerr_in),

  // TX Initialization
  .gt1_txpcsreset_in           (gt1_txpcsreset_in),
  .gt1_txpmareset_in           (gt1_txpmareset_in),

  // TX Buffer Ports
  .gt1_txbufstatus_out         (gt1_txbufstatus_out),

  // Rx CDR Ports
  .gt1_rxcdrhold_in            (gt1_rxcdrhold_in),

  // Receive Ports - Pattern Checker ports
  .gt1_rxprbserr_out           (gt1_rxprbserr_out),
  .gt1_rxprbssel_in            (gt1_rxprbssel_in),
  .gt1_rxprbscntreset_in       (gt1_rxprbscntreset_in),

  // RX Buffer Bypass Ports
  .gt1_rxbufreset_in           (gt1_rxbufreset_in),
  .gt1_rxbufstatus_out         (gt1_rxbufstatus_out),
  .gt1_rxstatus_out            (gt1_rxstatus_out),

  // RX Byte and Word Alignment Ports
  .gt1_rxbyteisaligned_out     (gt1_rxbyteisaligned_out),
  .gt1_rxbyterealign_out       (gt1_rxbyterealign_out),
  .gt1_rxcommadet_out          (gt1_rxcommadet_out),

  // Digital Monitor Ports
  .gt1_dmonitorout_out         (gt1_dmonitorout_out),


  // RX Initialization and Reset Ports
  .gt1_rxpcsreset_in           (gt1_rxpcsreset_in),
  .gt1_rxpmareset_in           (gt1_rxpmareset_in),

  // Receive Ports - RX Equalizer Ports
  .gt1_rxlpmen_in              (gt1_rxlpmen_in),
  .gt1_rxdfelpmreset_in        (gt1_rxdfelpmreset_in),
  .gt1_rxmonitorout_out        (gt1_rxmonitorout_out),
  .gt1_rxmonitorsel_in         (gt1_rxmonitorsel_in),

  // GT Reset Done Outputs
  .gt2_txresetdone_out         (gt2_txresetdone_out),
  .gt2_rxresetdone_out         (gt2_rxresetdone_out),

  .gt2_cplllock_out            (gt2_cplllock_out),

  // Loopback
  .gt2_loopback_in             (gt2_loopback_in),

  // Power Down Ports
  .gt2_rxpd_in                 (gt2_rxpd_in),
  .gt2_txpd_in                 (gt2_txpd_in),

  // GT Tx Control
  .gt2_txpostcursor_in         (gt2_txpostcursor_in),
  .gt2_txprecursor_in          (gt2_txprecursor_in),
  .gt2_txdiffctrl_in           (gt2_txdiffctrl_in),
  .gt2_txpolarity_in           (gt2_txpolarity_in),
  .gt2_txinhibit_in            (gt2_txinhibit_in),

  // Rx Polarity Port
  .gt2_rxpolarity_in           (gt2_rxpolarity_in),

  // DRP Ports
  .gt2_drpaddr                 (gt2_drpaddr),
  .gt2_drpdi                   (gt2_drpdi),
  .gt2_drpen                   (gt2_drpen),
  .gt2_drpwe                   (gt2_drpwe),
  .gt2_drpdo                   (gt2_drpdo),
  .gt2_drprdy                  (gt2_drprdy),

  // RX Margin Analysis Ports
  .gt2_eyescandataerror_out    (gt2_eyescandataerror_out),
  .gt2_eyescantrigger_in       (gt2_eyescantrigger_in),
  .gt2_eyescanreset_in         (gt2_eyescanreset_in),

  // TX Pattern Checker ports
  .gt2_txprbsforceerr_in       (gt2_txprbsforceerr_in),

  // TX Initialization
  .gt2_txpcsreset_in           (gt2_txpcsreset_in),
  .gt2_txpmareset_in           (gt2_txpmareset_in),

  // TX Buffer Ports
  .gt2_txbufstatus_out         (gt2_txbufstatus_out),

  // Rx CDR Ports
  .gt2_rxcdrhold_in            (gt2_rxcdrhold_in),

  // Receive Ports - Pattern Checker ports
  .gt2_rxprbserr_out           (gt2_rxprbserr_out),
  .gt2_rxprbssel_in            (gt2_rxprbssel_in),
  .gt2_rxprbscntreset_in       (gt2_rxprbscntreset_in),

  // RX Buffer Bypass Ports
  .gt2_rxbufreset_in           (gt2_rxbufreset_in),
  .gt2_rxbufstatus_out         (gt2_rxbufstatus_out),
  .gt2_rxstatus_out            (gt2_rxstatus_out),

  // RX Byte and Word Alignment Ports
  .gt2_rxbyteisaligned_out     (gt2_rxbyteisaligned_out),
  .gt2_rxbyterealign_out       (gt2_rxbyterealign_out),
  .gt2_rxcommadet_out          (gt2_rxcommadet_out),

  // Digital Monitor Ports
  .gt2_dmonitorout_out         (gt2_dmonitorout_out),


  // RX Initialization and Reset Ports
  .gt2_rxpcsreset_in           (gt2_rxpcsreset_in),
  .gt2_rxpmareset_in           (gt2_rxpmareset_in),

  // Receive Ports - RX Equalizer Ports
  .gt2_rxlpmen_in              (gt2_rxlpmen_in),
  .gt2_rxdfelpmreset_in        (gt2_rxdfelpmreset_in),
  .gt2_rxmonitorout_out        (gt2_rxmonitorout_out),
  .gt2_rxmonitorsel_in         (gt2_rxmonitorsel_in),

  // GT Reset Done Outputs
  .gt3_txresetdone_out         (gt3_txresetdone_out),
  .gt3_rxresetdone_out         (gt3_rxresetdone_out),

  .gt3_cplllock_out            (gt3_cplllock_out),

  // Loopback
  .gt3_loopback_in             (gt3_loopback_in),

  // Power Down Ports
  .gt3_rxpd_in                 (gt3_rxpd_in),
  .gt3_txpd_in                 (gt3_txpd_in),

  // GT Tx Control
  .gt3_txpostcursor_in         (gt3_txpostcursor_in),
  .gt3_txprecursor_in          (gt3_txprecursor_in),
  .gt3_txdiffctrl_in           (gt3_txdiffctrl_in),
  .gt3_txpolarity_in           (gt3_txpolarity_in),
  .gt3_txinhibit_in            (gt3_txinhibit_in),

  // Rx Polarity Port
  .gt3_rxpolarity_in           (gt3_rxpolarity_in),

  // DRP Ports
  .gt3_drpaddr                 (gt3_drpaddr),
  .gt3_drpdi                   (gt3_drpdi),
  .gt3_drpen                   (gt3_drpen),
  .gt3_drpwe                   (gt3_drpwe),
  .gt3_drpdo                   (gt3_drpdo),
  .gt3_drprdy                  (gt3_drprdy),

  // RX Margin Analysis Ports
  .gt3_eyescandataerror_out    (gt3_eyescandataerror_out),
  .gt3_eyescantrigger_in       (gt3_eyescantrigger_in),
  .gt3_eyescanreset_in         (gt3_eyescanreset_in),

  // TX Pattern Checker ports
  .gt3_txprbsforceerr_in       (gt3_txprbsforceerr_in),

  // TX Initialization
  .gt3_txpcsreset_in           (gt3_txpcsreset_in),
  .gt3_txpmareset_in           (gt3_txpmareset_in),

  // TX Buffer Ports
  .gt3_txbufstatus_out         (gt3_txbufstatus_out),

  // Rx CDR Ports
  .gt3_rxcdrhold_in            (gt3_rxcdrhold_in),

  // Receive Ports - Pattern Checker ports
  .gt3_rxprbserr_out           (gt3_rxprbserr_out),
  .gt3_rxprbssel_in            (gt3_rxprbssel_in),
  .gt3_rxprbscntreset_in       (gt3_rxprbscntreset_in),

  // RX Buffer Bypass Ports
  .gt3_rxbufreset_in           (gt3_rxbufreset_in),
  .gt3_rxbufstatus_out         (gt3_rxbufstatus_out),
  .gt3_rxstatus_out            (gt3_rxstatus_out),

  // RX Byte and Word Alignment Ports
  .gt3_rxbyteisaligned_out     (gt3_rxbyteisaligned_out),
  .gt3_rxbyterealign_out       (gt3_rxbyterealign_out),
  .gt3_rxcommadet_out          (gt3_rxcommadet_out),

  // Digital Monitor Ports
  .gt3_dmonitorout_out         (gt3_dmonitorout_out),


  // RX Initialization and Reset Ports
  .gt3_rxpcsreset_in           (gt3_rxpcsreset_in),
  .gt3_rxpmareset_in           (gt3_rxpmareset_in),

  // Receive Ports - RX Equalizer Ports
  .gt3_rxlpmen_in              (gt3_rxlpmen_in),
  .gt3_rxdfelpmreset_in        (gt3_rxdfelpmreset_in),
  .gt3_rxmonitorout_out        (gt3_rxmonitorout_out),
  .gt3_rxmonitorsel_in         (gt3_rxmonitorsel_in),

  // System Reset Inputs for each direction
  .tx_sys_reset           (tx_sys_reset),
  .rx_sys_reset           (rx_sys_reset),
  
  // Reset Inputs for each direction
  .tx_reset_gt            (tx_reset_gt),
  .rx_reset_gt            (rx_reset_gt),

  // Reset Done for each direction
  .tx_reset_done          (tx_reset_done),
  .rx_reset_done          (rx_reset_done),

  .gt_prbssel             (gt_prbssel),

  .cpll_refclk            (cpll_refclk),
  // GT Common I/O
  .common0_qpll_refclk_in   (common0_qpll_refclk_i),
  .common0_qpll_clk_in      (common0_qpll_clk_i),

  .rxencommaalign          (rxencommaalign),

  // Clocks
  .tx_core_clk             (tx_core_clk),
  .txoutclk                (txoutclk),

  .rx_core_clk             (rx_core_clk),
  .rxoutclk                (rxoutclk),
  .drpclk                  (drpclk),

  // Tx Ports
  // Lane 0
  .gt0_txdata              (gt0_txdata),
  .gt0_txcharisk           (gt0_txcharisk),

  // Lane 1
  .gt1_txdata              (gt1_txdata),
  .gt1_txcharisk           (gt1_txcharisk),

  // Lane 2
  .gt2_txdata              (gt2_txdata),
  .gt2_txcharisk           (gt2_txcharisk),

  // Lane 3
  .gt3_txdata              (gt3_txdata),
  .gt3_txcharisk           (gt3_txcharisk),

  // Rx Ports
  // Lane 0
  .gt0_rxdata              (gt0_rxdata),
  .gt0_rxcharisk           (gt0_rxcharisk),
  .gt0_rxdisperr           (gt0_rxdisperr),
  .gt0_rxnotintable        (gt0_rxnotintable),

  // Lane 1
  .gt1_rxdata              (gt1_rxdata),
  .gt1_rxcharisk           (gt1_rxcharisk),
  .gt1_rxdisperr           (gt1_rxdisperr),
  .gt1_rxnotintable        (gt1_rxnotintable),

  // Lane 2
  .gt2_rxdata              (gt2_rxdata),
  .gt2_rxcharisk           (gt2_rxcharisk),
  .gt2_rxdisperr           (gt2_rxdisperr),
  .gt2_rxnotintable        (gt2_rxnotintable),

  // Lane 3
  .gt3_rxdata              (gt3_rxdata),
  .gt3_rxcharisk           (gt3_rxcharisk),
  .gt3_rxdisperr           (gt3_rxdisperr),
  .gt3_rxnotintable        (gt3_rxnotintable),

  // Serial ports
  .rxn_in                  (rxn_in),
  .rxp_in                  (rxp_in),
  .txn_out                 (txn_out),
  .txp_out                 (txp_out)
  );

// *******************************************
// Instantiate Common GT Module
// *******************************************
ayadc_jesd204_phy_gt_common_wrapper
jesd204_phy_gt_common_i
  (
  // Common 0 DRP Ports
  .common_drpclk_in         (1'b0),
  .gt0_common_drpaddr_in    (8'h00),
  .gt0_common_drpdi_in      (16'h0000),
  .gt0_common_drpen_in      (1'b0),
  .gt0_common_drpwe_in      (1'b0),
  .gt0_common_drpdo_out     (),
  .gt0_common_drprdy_out    (),

  // Common 0 Ref Clock Ports
  .gt0_gtrefclk0_common_in  (cpll_refclk),

  // Common 0 QPLL Ports
  .gt0_qplllock_out         (common0_qpll_lock_i),
  .gt0_qpllpd_in            (1'b1),
  .gt0_qpllreset_in         (1'b0),
  .gt0_qplloutrefclk_out    (common0_qpll_refclk_i),
  .gt0_qplloutclk_out       (common0_qpll_clk_i)
  );


endmodule

