----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/19/2025 04:35:31 PM
-- Design Name: 
-- Module Name: SegmentsReg - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;


entity SegmentsReg is
    Port (
        CLK           : in  std_logic; 
        RST           : in  std_logic; 
        
        -- Data Inputs
        NEW_IP_IN     : in  std_logic_vector(15 downto 0); -- NEW IP value from AddressCalculator
        
        -- Outputs (to BIU Address Calculus Unit)
        CS_OUT        : out std_logic_vector(15 downto 0); -- Code Segment Register Value
        IP_OUT        : out std_logic_vector(15 downto 0); -- Instruction Pointer (Offset) Value
        DS_OUT        : out std_logic_vector(15 downto 0); -- Data Segment Register Value
        SS_OUT        : out std_logic_vector(15 downto 0); -- Stack Segment Register Value
        ES_OUT        : out std_logic_vector(15 downto 0)  -- Extra Segment Register Value
    );
end entity SegmentsReg;

architecture Behavioral of SegmentsReg is

    -- Initial Segment Address Constants
    constant C_DS_INIT : std_logic_vector(15 downto 0) := x"0020"; -- Data Segment Start (00200h)
    constant C_CS_INIT : std_logic_vector(15 downto 0) := x"0000"; -- Code Segment Start (00000h)
    constant C_SS_INIT : std_logic_vector(15 downto 0) := x"0040"; -- Stack Segment Start (00400h)
    constant C_ES_INIT : std_logic_vector(15 downto 0) := x"0040"; -- Extra Segment Start (00400h)

    -- Internal Register Signals (Default to 16-bit, all initialized to 0)
    signal CS_REG : std_logic_vector(15 downto 0) := C_CS_INIT;
    signal IP_REG : std_logic_vector(15 downto 0) := (others => '0');
    signal DS_REG : std_logic_vector(15 downto 0) := C_DS_INIT;
    signal SS_REG : std_logic_vector(15 downto 0) := C_SS_INIT;
    signal ES_REG : std_logic_vector(15 downto 0) := C_ES_INIT;

begin

    Register_Update_Process: process (CLK, RST) 
    begin
        if rst = '1' then
            DS_REG <= C_DS_INIT;
            CS_REG <= C_CS_INIT;
            SS_REG <= C_SS_INIT;
            ES_REG <= C_ES_INIT;
            IP_REG <= (others => '0');

        elsif rising_edge(CLK) then
            IP_REG <= NEW_IP_IN;            
        end if;
    end process Register_Update_Process;
    
    CS_OUT <= CS_REG;
    IP_OUT <= IP_REG;
    DS_OUT <= DS_REG;
    SS_OUT <= SS_REG;
    ES_OUT <= ES_REG;

end architecture Behavioral;
