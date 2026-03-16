----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/19/2025 05:08:55 PM
-- Design Name: 
-- Module Name: AddressCalculator - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;


entity AddressCalculator is
    port (
        -- Current Register Inputs (from SegmentsReg)
        CS_IN                       : in  std_logic_vector(15 downto 0);
        IP_IN                       : in  std_logic_vector(15 downto 0);
        DS_IN                       : in  std_logic_vector(15 downto 0);
        SS_IN                       : in  std_logic_vector(15 downto 0);
        ES_IN                       : in  std_logic_vector(15 downto 0);

        -- Input for Data Access Offset
        DATA_OFFSET_IN              : in  std_logic_vector(15 downto 0);

        -- Control and Data for Non-Sequential Jumps
        JUMP_EN                     : in  std_logic;
        TARGET_ADDR_IN              : in  std_logic_vector(19 downto 0);
        
        -- Control from BIU FSM
        INCREMENT_IP_EN             : in  std_logic;                   

        -- Outputs
        CURRENT_PHYSICAL_ADDR_OUT   : out std_logic_vector(19 downto 0);
        DATA_PHYSICAL_ADDR_OUT      : out std_logic_vector(19 downto 0);
        NEXT_IP_OUT                 : out std_logic_vector(15 downto 0) 
    );
end entity AddressCalculator;


architecture rtl_proc of AddressCalculator is

signal s_data_physical_addr : std_logic_vector(19 downto 0);

begin

    Addr_Calc_Process: process(CS_IN, IP_IN, DS_IN, DATA_OFFSET_IN, JUMP_EN, TARGET_ADDR_IN, INCREMENT_IP_EN)
        -- Internal variables for 20-bit Arithmetic
        variable v_cs_segment_base_20 : unsigned(19 downto 0);
        variable v_current_ip_20      : unsigned(19 downto 0);
        variable v_ds_segment_base_20 : unsigned(19 downto 0);
        
        -- Internal variables for 16-bit Arithmetic
        variable v_ip_in_16                  : unsigned(15 downto 0);
        variable v_sequential_next_ip_16     : unsigned(15 downto 0);
        variable v_jump_next_ip_16           : unsigned(15 downto 0);

        -- Temporary variable for jump calculation
        variable v_temp_jump_addr : unsigned(19 downto 0);
    
    begin
        
        -- Convert inputs for arithmetic
        v_ip_in_16 := unsigned(IP_IN);
        v_cs_segment_base_20 := unsigned(CS_IN & "0000");

        -- == 1. Instruction Fetch Physical Address (CS:IP) ==
        v_current_ip_20 := unsigned("0000" & IP_IN);
        CURRENT_PHYSICAL_ADDR_OUT <= std_logic_vector(v_cs_segment_base_20 + v_current_ip_20);

        -- == 2. Data Access Physical Address (DS:Offset) ==
        v_ds_segment_base_20 := unsigned(DS_IN & "0000");
        s_data_physical_addr <= std_logic_vector(v_ds_segment_base_20 + unsigned("0000" & DATA_OFFSET_IN));

        -- == 3. Next IP Calculation Logic ==

        -- a) Sequential Next IP (IP + 2)
        v_sequential_next_ip_16 := v_ip_in_16 + 2;

        -- b) Jump Next IP
        v_temp_jump_addr    := (unsigned(TARGET_ADDR_IN) sll 1) - v_cs_segment_base_20;
        v_jump_next_ip_16   := v_temp_jump_addr(15 downto 0);

        -- c) Select Final Next IP Value
        if JUMP_EN = '1' then
            NEXT_IP_OUT <= std_logic_vector(v_jump_next_ip_16);
        elsif INCREMENT_IP_EN = '1' then
            NEXT_IP_OUT <= std_logic_vector(v_sequential_next_ip_16);
        else
            NEXT_IP_OUT <= IP_IN; 
        end if;

    end process Addr_Calc_Process;
    
    DATA_PHYSICAL_ADDR_OUT <= s_data_physical_addr;
    
end architecture rtl_proc;
    

