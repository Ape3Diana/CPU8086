----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/19/2025 07:35:46 PM
-- Design Name: 
-- Module Name: OneBitALU - Behavioral
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

entity OneBitALU is
    Port (
        -- Data Inputs
        A_IN    : in  std_logic;
        B_IN    : in  std_logic;
        
        -- Arithmetic Control and Chain
        C_IN    : in  std_logic;    -- Carry/Borrow In
        SUB_SEL : in  std_logic;    -- '0' = Add, '1' = Subtract (inverts B_IN)

        -- Function Selector (3 bits used for 4 core functions)
        FUNC_SEL : in std_logic_vector(1 downto 0); -- 00=ADD/SUB, 01=AND, 10=OR, 11=XOR

        -- Outputs
        RESULT  : out std_logic;
        C_OUT   : out std_logic     -- Carry/Borrow Out
    );
end entity OneBitALU;

architecture Behavioral of OneBitALU is

    -- Signal for B inverted during subtraction (B_IN XOR SUB_SEL)
    signal B_MODIFIED : std_logic;
    
    -- Internal signals for the arithmetic result (Sum and Carry)
    signal SUM_BIT    : std_logic;
    signal C_SUM      : std_logic;

begin
    -- ----------------------------------------------------------------------
    -- Arithmetic Path (Full Adder/Subtractor)
    -- ----------------------------------------------------------------------
    -- If SUB_SEL is '1', B is inverted (A + ~B + 1 = A - B). C_IN will be '1' for bit 0.
    B_MODIFIED <= B_IN xor SUB_SEL;
    
    -- Sum logic (A xor B_modified xor C_IN)
    SUM_BIT <= A_IN xor B_MODIFIED xor C_IN;
    
    -- Carry/Borrow out logic
    C_SUM <= (A_IN and B_MODIFIED) or (C_IN and A_IN) or (C_IN and B_MODIFIED);
    
    -- ----------------------------------------------------------------------
    -- Result Multiplexer (Functional Block)
    -- ----------------------------------------------------------------------
    process(A_IN, B_IN, SUM_BIT, C_SUM, FUNC_SEL)
    begin
        case FUNC_SEL is
            -- 00: ADD / SUB (Arithmetic)
            when "00" => 
                RESULT <= SUM_BIT;
                C_OUT  <= C_SUM;
            
            -- 01: AND
            when "01" => 
                RESULT <= A_IN and B_IN;
                C_OUT  <= '0'; -- Carry not used for logic
            
            -- 10: OR
            when "10" =>
                RESULT <= A_IN or B_IN;
                C_OUT  <= '0';
            
            -- 11: XOR
            when "11" =>
                RESULT <= A_IN xor B_IN;
                C_OUT  <= '0';
                
            when others =>
                RESULT <= 'Z';
                C_OUT  <= '0';
        end case;
    end process;

end architecture Behavioral;

