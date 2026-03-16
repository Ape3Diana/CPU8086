----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/19/2025 07:40:46 PM
-- Design Name: 
-- Module Name: ALU16b - Behavioral
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

entity ALU16b is
    Port (
        -- Control Input (from Control Unit)
        ALU_OP_SEL : in  std_logic_vector(3 downto 0); 
        
        -- Data Inputs
        DATA_IN_A  : in  std_logic_vector(15 downto 0);
        DATA_IN_B  : in  std_logic_vector(15 downto 0);
        SHIFT_IMM  : in  std_logic_vector(4 downto 0);

        -- ALU Output
        ALU_OUT    : out std_logic_vector(15 downto 0);
        
        -- Flags Outputs (Combinational)
        FLAGS_OUT_16 : out std_logic_vector(3 downto 0); -- S, O, C, Z for 16-bit
        FLAGS_OUT_8  : out std_logic_vector(3 downto 0)  -- S, O, C, Z for 8-bit
    );
end entity ALU16b;

architecture Behavioral of ALU16b is

    component OneBitALU
        Port (
            A_IN     : in  std_logic;
            B_IN     : in  std_logic;
            C_IN     : in  std_logic;
            SUB_SEL  : in  std_logic;
            FUNC_SEL : in  std_logic_vector(1 downto 0);
            RESULT   : out std_logic;
            C_OUT    : out std_logic
        );
    end component OneBitALU;

    -- ALU Control Signals (driven by ALU_OP_SEL)
    signal ALU_FUNC_SEL_2B : std_logic_vector(1 downto 0);  
    signal ALU_SUB_SEL     : std_logic;                     
    signal ALU_CARRY_IN    : std_logic;                     

    -- Operand Selection Signals
    signal OPERAND_B_CALC : std_logic_vector(15 downto 0); -- B input for core
    
    -- Internal ALU Chain Signals
    signal ALU_CORE_RESULT : std_logic_vector(15 downto 0);
    signal ALU_CARRY       : std_logic_vector(15 downto 0); 
    signal FINAL_CARRY     : std_logic;                     

    -- Barrel Shifter Signals
    signal SHIFTER_OUT : std_logic_vector(15 downto 0);

    -- Flags Calculation Signals
    signal CALC_Z_FLAG, CALC_S_FLAG, CALC_C_FLAG, CALC_O_FLAG : std_logic;
    
    -- Constants for ALU_OP_SEL (to be shared with ControlUnit)
    constant OP_ADD     : std_logic_vector(3 downto 0) := "0000";
    constant OP_SUB     : std_logic_vector(3 downto 0) := "0001";
    constant OP_INC     : std_logic_vector(3 downto 0) := "0010";
    constant OP_DEC     : std_logic_vector(3 downto 0) := "0011";
    constant OP_AND     : std_logic_vector(3 downto 0) := "0100";
    constant OP_OR      : std_logic_vector(3 downto 0) := "0101";
    constant OP_XOR     : std_logic_vector(3 downto 0) := "0110";
    constant OP_NOT     : std_logic_vector(3 downto 0) := "0111";
    constant OP_SHL     : std_logic_vector(3 downto 0) := "1000";
    constant OP_SHR     : std_logic_vector(3 downto 0) := "1001";
    constant OP_PASS_B  : std_logic_vector(3 downto 0) := "1010"; -- For MOV/LIR/LDR
    
    
    -- === 5. Flag Calculation (Purely Combinational) ===

    -- Internal Signals for 16-bit flags
    signal s16, o16, c16, z16 : std_logic;
    -- Internal Signals for 8-bit flags
    signal s8, o8, c8, z8 : std_logic;

begin

    -- === 1. ALU Control Signal Generation (Combinational) ===
   
    process(ALU_OP_SEL, DATA_IN_B)
    begin
        -- Default/Safe values
        ALU_FUNC_SEL_2B <= "00"; -- ADD
        ALU_SUB_SEL     <= '0'; 
        ALU_CARRY_IN    <= '0'; 
        OPERAND_B_CALC  <= DATA_IN_B; -- Default to external MUX
        
        case ALU_OP_SEL is
            -- 0000: ADD
            when OP_ADD =>
                null; -- Uses defaults
            
            -- 0001: SUB / CMP
            when OP_SUB =>
                ALU_SUB_SEL  <= '1'; -- SUB (B is inverted)
                ALU_CARRY_IN <= '1'; -- Cin=1 for A + ~B + 1
            
            -- 0010: INC
            when OP_INC =>
                ALU_CARRY_IN   <= '1'; -- Add 1
                OPERAND_B_CALC <= (others => '0'); -- A + 0 + 1
            
            -- 0011: DEC
            when OP_DEC =>
                ALU_SUB_SEL    <= '1'; -- SUB 
                ALU_CARRY_IN   <= '1'; -- A + ~1 + 0 = A - 1
                OPERAND_B_CALC <= X"0001"; -- B = 1
                
            -- 0100: AND
            when OP_AND =>
                ALU_FUNC_SEL_2B <= "01";
            
            -- 0101: OR
            when OP_OR =>
                ALU_FUNC_SEL_2B <= "10";
            
            -- 0110: XOR
            when OP_XOR =>
                ALU_FUNC_SEL_2B <= "11";
                
            -- 0111: NOT
            when OP_NOT =>
                ALU_FUNC_SEL_2B <= "11"; -- XOR (NOT A = A XOR 0xFFFF)
                OPERAND_B_CALC  <= (others => '1'); 
                
            -- 1000: SHL, 1001: SHR, 1010: PASS_B
            when OP_SHL | OP_SHR | OP_PASS_B =>
                -- These ops bypass the ripple-carry core
                null; 
                
            when others =>
                null;
        end case;
    end process;
    
    -- === 2. Arithmetic/Logic Core ===

    CORE_LSB: OneBitALU
        Port Map (
            A_IN     => DATA_IN_A(0),
            B_IN     => OPERAND_B_CALC(0),
            C_IN     => ALU_CARRY_IN,
            SUB_SEL  => ALU_SUB_SEL,
            FUNC_SEL => ALU_FUNC_SEL_2B,
            RESULT   => ALU_CORE_RESULT(0),
            C_OUT    => ALU_CARRY(0)
        );

    ALU_CHAIN: for I in 1 to 15 generate
        CORE_BIT: OneBitALU
            Port Map (
                A_IN     => DATA_IN_A(I),
                B_IN     => OPERAND_B_CALC(I),
                C_IN     => ALU_CARRY(I-1),
                SUB_SEL  => ALU_SUB_SEL,
                FUNC_SEL => ALU_FUNC_SEL_2B,
                RESULT   => ALU_CORE_RESULT(I),
                C_OUT    => ALU_CARRY(I)
            );
    end generate ALU_CHAIN;
    
    FINAL_CARRY <= ALU_CARRY(15);

    -- === 3. Shifter Block (SHL/SHR) ===

        process(ALU_OP_SEL, DATA_IN_A, SHIFT_IMM)
            -- Use a 5-bit shift amount (0 to 31)
            variable V_SHIFT_AMOUNT : integer range 0 to 31;
            variable V_SHIFTER_OUT  : std_logic_vector(15 downto 0);
        begin
            V_SHIFT_AMOUNT := to_integer(unsigned(SHIFT_IMM));
            
            if ALU_OP_SEL = OP_SHL then
                V_SHIFTER_OUT := std_logic_vector(shift_left(unsigned(DATA_IN_A), V_SHIFT_AMOUNT));
            elsif ALU_OP_SEL = OP_SHR then
                V_SHIFTER_OUT := std_logic_vector(shift_right(unsigned(DATA_IN_A), V_SHIFT_AMOUNT));
            else
                -- Default case: not a shift op
                V_SHIFTER_OUT := DATA_IN_A;
            end if;
            
            SHIFTER_OUT <= V_SHIFTER_OUT;
        end process;
    

    -- === 4. Final Result Multiplexer (Combinational) ===

    with ALU_OP_SEL select
        ALU_OUT <= 
            ALU_CORE_RESULT when OP_ADD | OP_SUB | OP_INC | OP_DEC | OP_AND | OP_OR | OP_XOR | OP_NOT,
            SHIFTER_OUT     when OP_SHL | OP_SHR,
            DATA_IN_B       when OP_PASS_B, -- For MOV, LIR, LDR
            (others => '0') when others;


    -- === 5. Flag Calculation (Combinational) ===

    -- 16-bit Flag Calculation Process
    process(ALU_CORE_RESULT, FINAL_CARRY, ALU_CARRY)
    begin
        -- Z Flag: Set if 16-bit result is all zero
        if ALU_CORE_RESULT = "0000000000000000"  then
            z16 <= '1';
        else
            z16 <= '0';
        end if;

        -- S Flag: 16-bit Sign (MSB)
        s16 <= ALU_CORE_RESULT(15);
        
        -- C Flag: 16-bit Carry Out
        c16 <= FINAL_CARRY; -- This is ALU_CARRY(15)
        
        -- O Flag: 16-bit Overflow (C15 xor C14)
        o16 <= ALU_CARRY(15) xor ALU_CARRY(14);
    end process;

    -- 8-bit Flag Calculation Process
    process(ALU_CORE_RESULT, ALU_CARRY, ALU_SUB_SEL)
    begin
        -- Z Flag: Set if 8-bit (low byte) result is all zero
        if ALU_CORE_RESULT(7 downto 0) = "00000000" then
            z8 <= '1';
        else
            z8 <= '0';
        end if;

        -- S Flag: 8-bit Sign (MSB of low byte)
        s8 <= ALU_CORE_RESULT(7);
        
        -- C Flag: 8-bit Carry Out
        c8 <= ALU_CARRY(7) xor ALU_SUB_SEL;
        
        -- O Flag: 8-bit Overflow (C7 xor C6)
        o8 <= ALU_CARRY(7) xor ALU_CARRY(6);
    end process;

    -- Assign to output ports (S, O, C, Z)
    FLAGS_OUT_16 <= s16 & o16 & c16 & z16;
    FLAGS_OUT_8  <= s8 & o8 & c8 & z8;

end architecture Behavioral;



