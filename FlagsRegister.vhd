----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/25/2025 03:21:37 PM
-- Design Name: 
-- Module Name: FlagsRegister - Behavioral
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

entity FlagsRegister is
    Port (
        CLK : in  std_logic;
        RST : in  std_logic;
        
        -- === Write Port (from Control Unit / Flag MUX) ===
        FLAG_WRITE_EN : in  std_logic;                     -- Write enable from ControlUnit
        FLAGS_IN      : in  std_logic_vector(3 downto 0);  -- New S,O,C,Z values from Flag MUX
        
        -- === Read Port (to Control Unit) ===
        FLAGS_OUT     : out std_logic_vector(3 downto 0)   -- Current S,O,C,Z values
    );
end entity FlagsRegister;

architecture Behavioral of FlagsRegister is
    
    signal s_flags_reg : std_logic_vector(3 downto 0) := "0000"; -- S,O,C,Z

begin

    Flags_Update_Process: process (CLK, RST)
    begin
        if RST = '1' then
            s_flags_reg <= "0000";
            
        elsif rising_edge(CLK) then
            if FLAG_WRITE_EN = '1' then
                s_flags_reg <= FLAGS_IN;
            end if;
        end if;
    end process Flags_Update_Process;
    
    FLAGS_OUT <= s_flags_reg;

end architecture Behavioral;
