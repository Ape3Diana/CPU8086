----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/22/2025 11:10:40 AM
-- Design Name: 
-- Module Name: Control_Unit - Behavioral
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

entity ControlUnit is
    Port (
        CLK             : in  std_logic;
        RST             : in  std_logic;
        STEP_BUTTON_IN  : in  std_logic; 

        -- === From FIFO (BIU) ===
        INSTRUCTION_IN  : in  std_logic_vector(15 downto 0);
        FIFO_EMPTY      : in  std_logic;

        -- === From RAM (BIU) ===
        MEM_DATA_IN     : in  std_logic_vector(15 downto 0); -- From RAM.DATA_READ

        -- === From Flags Register ===
        CURRENT_FLAGS   : in  std_logic_vector(3 downto 0);  -- S, O, C, Z
        
        -- === To FIFO (BIU) ===
        FIFO_READ_EN    : out std_logic;

        -- === To BIU (Address/Jump Control) ===
        DATA_OFFSET_OUT : out std_logic_vector(15 downto 0); -- To AddrCalc.DATA_OFFSET_IN
        MEM_WRITE_EN    : out std_logic;                     -- To RAM.WRITE_EN
        BIU_JUMP_EN     : out std_logic;                     -- To AddrCalc.JUMP_EN
        BIU_FLUSH       : out std_logic;                     -- To FIFO.FLUSH
        BIU_JUMP_TARGET : out std_logic_vector(19 downto 0); -- To AddrCalc.TARGET_ADDR_IN

        -- === To Register File ===
        REG_READ_ADDR_A : out std_logic_vector(2 downto 0); -- 'ddd' field (Operand A)
        REG_READ_ADDR_B : out std_logic_vector(2 downto 0); -- 'sss' field (Operand B)
        REG_WRITE_ADDR  : out std_logic_vector(2 downto 0); -- 'ddd' field (Destination)
        REG_WRITE_EN    : out std_logic;
        SIZE_SEL_8_16   : out std_logic; -- 's' bit 

        -- === To ALU ===
        ALU_OP_SEL      : out std_logic_vector(3 downto 0);

        -- === To Operand-B MUX ===
        -- (This MUX selects the ALU's DATA_IN_B)
        -- 00 = RegFile_B, 01 = Mem_Data_In, 10 = Immediate
        ALU_IN_B_MUX_SEL : out std_logic_vector(1 downto 0);

        -- === To Flags Register ===
        FLAG_REG_WRITE_EN : out std_logic;
        
        IR_OUT : out std_logic_vector(15 downto 0)
    );
end entity ControlUnit;

architecture Behavioral of ControlUnit is

    -- Internal Instruction Register
    signal IR : std_logic_vector(15 downto 0) := (others => '0');
    
    -- Decoded Instruction Fields
    signal s_opcode : std_logic_vector(4 downto 0);
    signal s_size   : std_logic;
    signal s_ddd    : std_logic_vector(2 downto 0);
    signal s_sss    : std_logic_vector(2 downto 0);
    signal s_t_bit  : std_logic;
    signal s_imm7   : std_logic_vector(6 downto 0);
    signal s_addr7  : std_logic_vector(6 downto 0);
    signal s_addr6  : std_logic_vector(5 downto 0);
    signal s_imm4   : std_logic_vector(3 downto 0);
    signal s_jmp_addr11 : std_logic_vector(10 downto 0);

    -- ALU Op Constants
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
    constant OP_PASS_B  : std_logic_vector(3 downto 0) := "1010";

    -- ALU B-Mux Select Constants
    constant MUX_B_REGS : std_logic_vector(1 downto 0) := "00";
    constant MUX_B_MEM  : std_logic_vector(1 downto 0) := "01";
    constant MUX_B_IMM  : std_logic_vector(1 downto 0) := "10";

    -- State Machine
    type t_cu_state is (s_IDLE, s_DECODE, s_MEM_READ, s_EXECUTE, s_MEM_WRITE, s_JUMP);
    signal state : t_cu_state := s_IDLE;
    
    -- Internal signal for Zero Flag
    signal Z_FLAG : std_logic;
    
    signal s_data_offset : std_logic_vector(15 downto 0) := (others => '0');

begin

    IR_OUT <= IR;
    DATA_OFFSET_OUT <= s_data_offset;
    
    -- === 1. Concurrent Decoding & Flag Logic ===
    
    -- Latch decoded fields from the IR
    s_opcode     <= IR(15 downto 11);
    s_size       <= IR(10);
    s_ddd        <= IR(9 downto 7);
    s_sss        <= IR(6 downto 4);
    s_t_bit      <= IR(0);
    s_imm7       <= IR(6 downto 0);
    s_addr7      <= IR(6 downto 0);
    s_addr6      <= IR(6 downto 1);
    s_imm4       <= IR(6 downto 3);
    s_jmp_addr11 <= IR(10 downto 0);

    -- Extract Zero Flag
    Z_FLAG <= CURRENT_FLAGS(0);

    -- Assign register read port A (always active)
    REG_READ_ADDR_A <= s_ddd; -- Operand A is almost always RegDst
    
    -- Assign SIZE_SEL (always active)
    SIZE_SEL_8_16   <= s_size;

    -- === 2. Main Control State Machine ===
    process(CLK, RST)
    begin
        if RST = '1' then
            state <= s_IDLE;
            FIFO_READ_EN      <= '0';
            REG_WRITE_EN      <= '0';
            MEM_WRITE_EN      <= '0';
            FLAG_REG_WRITE_EN <= '0';
            BIU_JUMP_EN       <= '0';
            BIU_FLUSH         <= '0';
            REG_READ_ADDR_B   <= (others => '0'); 
            
        elsif rising_edge(CLK) then
        
            -- Default values for outputs (asserted only when needed)
            FIFO_READ_EN      <= '0';
            REG_WRITE_EN      <= '0';
            MEM_WRITE_EN      <= '0';
            FLAG_REG_WRITE_EN <= '0';
            BIU_JUMP_EN       <= '0';
            BIU_FLUSH         <= '0';

            -- Default MUX/Control values
            ALU_OP_SEL       <= OP_ADD;     -- Default to ADD
            ALU_IN_B_MUX_SEL <= MUX_B_REGS;
            REG_WRITE_ADDR   <= s_ddd;
            DATA_OFFSET_OUT  <= (others => '0');
            BIU_JUMP_TARGET  <= (others => '0');
            REG_READ_ADDR_B  <= s_sss; -- Default Read Addr B to s_sss (covers CMP, MOV, AND, OR, XOR)

            -- === STATE MACHINE LOGIC ===
            case state is
            
                -- IDLE: Wait for button press
                when s_IDLE =>
                    -- Latch and Read in the same cycle
                    if STEP_BUTTON_IN = '1' and FIFO_EMPTY = '0' then
                        FIFO_READ_EN <= '1';
                        IR             <= INSTRUCTION_IN; -- Latch instruction on *this* cycle
                        state          <= s_DECODE;       -- Go directly to DECODE
                    end if;
                
                -- DECODE: Set up all signals based on IR
                when s_DECODE =>
                    case s_opcode is
                    
                        -- === ALU Reg-Reg Ops ===
                        -- ADD (t=0), SUB (t=0)
                        when "00000" => -- ADD
                            if s_t_bit = '0' then -- Register mode
                                ALU_OP_SEL <= OP_ADD;
                                ALU_IN_B_MUX_SEL <= MUX_B_REGS;
                                REG_READ_ADDR_B <= s_addr6(2 downto 0); -- Override default s_sss
                                state <= s_EXECUTE;
                            else -- Memory mode
                                s_data_offset <= "0000000000" & s_addr6;
                                state <= s_MEM_READ;
                            end if;
                        when "00001" => -- SUB
                            if s_t_bit = '0' then -- Register mode
                                ALU_OP_SEL <= OP_SUB;
                                ALU_IN_B_MUX_SEL <= MUX_B_REGS;
                                REG_READ_ADDR_B <= s_addr6(2 downto 0); -- Override default s_sss
                                state <= s_EXECUTE;
                            else -- Memory mode
                                s_data_offset <= "0000000000" & s_addr6;            
                                state <= s_MEM_READ;
                            end if;

                        -- CMP, MOV, AND, OR, XOR (Use default REG_READ_ADDR_B <= s_sss;)
                        when "00101" => -- CMP
                            ALU_IN_B_MUX_SEL <= MUX_B_REGS;
                            ALU_OP_SEL <= OP_SUB;
                            state <= s_EXECUTE;
                        when "00110" => -- MOV
                            ALU_IN_B_MUX_SEL <= MUX_B_REGS;
                            ALU_OP_SEL <= OP_PASS_B;
                            state <= s_EXECUTE;
                        when "01010" => -- AND
                            ALU_IN_B_MUX_SEL <= MUX_B_REGS;
                            ALU_OP_SEL <= OP_AND;
                            state <= s_EXECUTE;
                        when "01011" => -- OR
                            ALU_IN_B_MUX_SEL <= MUX_B_REGS;
                            ALU_OP_SEL <= OP_OR;
                            state <= s_EXECUTE;
                        when "01100" => -- XOR
                            ALU_IN_B_MUX_SEL <= MUX_B_REGS;
                            ALU_OP_SEL <= OP_XOR;
                            state <= s_EXECUTE;
                        
                        -- === ALU Reg-Imm Ops ===
                        -- ADI, LIR, INC, DEC, NOT, SHL, SHR 
                        when "00010" => -- ADI
                            ALU_OP_SEL       <= OP_ADD;
                            ALU_IN_B_MUX_SEL <= MUX_B_IMM;
                            state <= s_EXECUTE;
                        when "00111" => -- LIR
                            ALU_OP_SEL       <= OP_PASS_B;
                            ALU_IN_B_MUX_SEL <= MUX_B_IMM;
                            state <= s_EXECUTE;
                        when "00011" => ALU_OP_SEL <= OP_INC; state <= s_EXECUTE;
                        when "00100" => ALU_OP_SEL <= OP_DEC; state <= s_EXECUTE;
                        when "01101" => ALU_OP_SEL <= OP_NOT; state <= s_EXECUTE;
                        when "01110" => ALU_OP_SEL <= OP_SHL; state <= s_EXECUTE;
                        when "01111" => ALU_OP_SEL <= OP_SHR; state <= s_EXECUTE;

                        -- === Memory Ops ===
                        when "01000" => -- LDR
                            s_data_offset <= "000000000" & s_addr7;
                            state <= s_MEM_READ;
                        when "01001" => -- STD
                            s_data_offset <= "000000000" & s_addr7;
                            state <= s_MEM_WRITE;
                            
                        -- === Jump/Misc Ops ===
                        when "10000" => state <= s_JUMP; -- JMP
                        when "10001" => state <= s_JUMP; -- JZ
                        when "10010" => state <= s_JUMP; -- JNZ
                            
                        when "10011" => -- NOOP
                            state <= s_IDLE;
                            
                        when others =>
                            state <= s_IDLE; -- Invalid opcode
                    end case;
                    
                -- MEM_READ: Wait for data from RAM (LDR, ADD-mem, SUB-mem)
                when s_MEM_READ =>
                    -- Setup MUX and ALU for the writeback on the *next* cycle
                    ALU_IN_B_MUX_SEL <= MUX_B_MEM;
                    if s_opcode = "01000" then -- LDR
                        ALU_OP_SEL <= OP_PASS_B;
                    elsif s_opcode = "00000" then -- ADD-mem
                        ALU_OP_SEL <= OP_ADD;
                    else -- SUB-mem (Opcode "00001" with t='1')
                        ALU_OP_SEL <= OP_SUB;
                    end if;
                    state <= s_EXECUTE;
              
                -- EXECUTE: ALU op is complete. Write back to registers.
                when s_EXECUTE =>
                    -- Only enable register write if it's NOT a CMP instruction
                    if s_opcode /= "00101" then -- (CMP Opcode)
                        REG_WRITE_EN <= '1'; -- Enable register write
                    end if;
                    
                    -- Only update flags for non-MOV/LIR/LDR instructions
                    if s_opcode /= "00110" and s_opcode /= "00111" and s_opcode /= "01000" then
                         FLAG_REG_WRITE_EN <= '1';
                    end if;
                    
                    case s_opcode is
                        -- === ALU Reg-Reg Ops ===
                        when "00000" => -- ADD
                            if s_t_bit = '0' then
                                ALU_OP_SEL <= OP_ADD;
                                ALU_IN_B_MUX_SEL <= MUX_B_REGS;
                                REG_READ_ADDR_B <= s_addr6(2 downto 0);
                            else -- This was a MEM_READ, re-assert those signals
                                ALU_OP_SEL <= OP_ADD;
                                ALU_IN_B_MUX_SEL <= MUX_B_MEM;
                            end if;
                        when "00001" => -- SUB
                            if s_t_bit = '0' then
                                ALU_OP_SEL <= OP_SUB;
                                ALU_IN_B_MUX_SEL <= MUX_B_REGS;
                                REG_READ_ADDR_B <= s_addr6(2 downto 0);
                            else -- This was a MEM_READ, re-assert those signals
                                ALU_OP_SEL <= OP_SUB;
                                ALU_IN_B_MUX_SEL <= MUX_B_MEM;
                            end if;
                            
                        -- === Reg-Reg Ops (using s_sss) ===
                        when "00101" => ALU_OP_SEL <= OP_SUB;    ALU_IN_B_MUX_SEL <= MUX_B_REGS; -- CMP
                        when "00110" => ALU_OP_SEL <= OP_PASS_B; ALU_IN_B_MUX_SEL <= MUX_B_REGS; -- MOV
                        when "01010" => ALU_OP_SEL <= OP_AND;    ALU_IN_B_MUX_SEL <= MUX_B_REGS; -- AND
                        when "01011" => ALU_OP_SEL <= OP_OR;     ALU_IN_B_MUX_SEL <= MUX_B_REGS; -- OR
                        when "01100" => ALU_OP_SEL <= OP_XOR;    ALU_IN_B_MUX_SEL <= MUX_B_REGS; -- XOR
                        
                        -- === Reg-Imm Ops ===
                        when "00010" => ALU_OP_SEL <= OP_ADD;    ALU_IN_B_MUX_SEL <= MUX_B_IMM; -- ADI
                        when "00111" => ALU_OP_SEL <= OP_PASS_B; ALU_IN_B_MUX_SEL <= MUX_B_IMM; -- LIR
                        when "00011" => ALU_OP_SEL <= OP_INC; -- INC
                        when "00100" => ALU_OP_SEL <= OP_DEC; -- DEC
                        when "01101" => ALU_OP_SEL <= OP_NOT; -- NOT
                        when "01110" => ALU_OP_SEL <= OP_SHL; -- SHL
                        when "01111" => ALU_OP_SEL <= OP_SHR; -- SHR

                        -- === Memory Ops ===
                       when "01000" => -- LDR (came from MEM_READ)
                            ALU_OP_SEL <= OP_PASS_B;
                            ALU_IN_B_MUX_SEL <= MUX_B_MEM;

                        -- Others (like STD, JMP, NOOP) don't use s_EXECUTE
                        when others => null;
                    end case;
                    
                    state <= s_IDLE;
                   
                -- MEM_WRITE: Send data to RAM
                when s_MEM_WRITE => -- STD
                    MEM_WRITE_EN <= '1';
                     state <= s_IDLE;
                    
                -- JUMP: Check flags and tell BIU to jump
                when s_JUMP =>
                    BIU_JUMP_TARGET <= "000000000" & s_jmp_addr11;
                    
                    if s_opcode = "10000" then -- JMP (Unconditional)
                       BIU_JUMP_EN <= '1';
                        BIU_FLUSH   <= '1';
                     elsif s_opcode = "10001" and Z_FLAG = '1' then -- JZ
                        BIU_JUMP_EN <= '1';
                        BIU_FLUSH   <= '1';
                    elsif s_opcode = "10010" and Z_FLAG = '0' then -- JNZ
                        BIU_JUMP_EN <= '1';
                        BIU_FLUSH   <= '1';
                    end if;
                    state <= s_IDLE;
          
            end case;
        end if;
    end process;

    
end architecture Behavioral;