----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/19/2025 06:41:44 PM
-- Design Name: 
-- Module Name: EU - Behavioral
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


entity EU is
    Port (
        CLK                 : in  std_logic;
        RST                 : in  std_logic;
        
        -- === From EU Control ===
        STEP_BUTTON_IN      : in  std_logic; 

        -- === From BIU (FIFO) ===
        INSTRUCTION_IN      : in  std_logic_vector(15 downto 0);
        FIFO_EMPTY          : in  std_logic;

        -- === From BIU (RAM Read Port) ===
        MEM_DATA_IN         : in  std_logic_vector(15 downto 0); -- From RAM.DATA_READ

        -- === To BIU (FIFO) ===
        FIFO_READ_EN        : out std_logic;

        -- === To BIU (Address/Jump Control) ===
        DATA_OFFSET_OUT     : out std_logic_vector(15 downto 0); -- To AddrCalc.DATA_OFFSET_IN
        BIU_JUMP_EN         : out std_logic;
        BIU_FLUSH           : out std_logic;
        BIU_JUMP_TARGET     : out std_logic_vector(19 downto 0);

        -- === To BIU (RAM Write Port) ===
        MEM_WRITE_EN        : out std_logic;                     -- To RAM.WRITE_EN
        MEM_DATA_OUT        : out std_logic_vector(15 downto 0); -- Data for STD
        
        -- === Register Outputs for Display ===
        AX_OUT              : out std_logic_vector(15 downto 0);
        BX_OUT              : out std_logic_vector(15 downto 0);
        CX_OUT              : out std_logic_vector(15 downto 0);
        DX_OUT              : out std_logic_vector(15 downto 0);
        CURRENT_FLAGS_OUT   : out std_logic_vector(3 downto 0); 
        
        -- to display the current instruction
        IR_OUT              : out std_logic_vector(15 downto 0)
    );
end entity EU;

architecture Behavioral of EU is

    component ControlUnit is
         Port (
            CLK               : in  std_logic;
            RST               : in  std_logic;
            STEP_BUTTON_IN    : in  std_logic;
            INSTRUCTION_IN    : in  std_logic_vector(15 downto 0);
            FIFO_EMPTY        : in  std_logic;
            MEM_DATA_IN       : in  std_logic_vector(15 downto 0);
            CURRENT_FLAGS     : in  std_logic_vector(3 downto 0);
            FIFO_READ_EN      : out std_logic;
            DATA_OFFSET_OUT   : out std_logic_vector(15 downto 0);
            MEM_WRITE_EN      : out std_logic;
            BIU_JUMP_EN       : out std_logic;
            BIU_FLUSH         : out std_logic;
            BIU_JUMP_TARGET   : out std_logic_vector(19 downto 0);
            REG_READ_ADDR_A   : out std_logic_vector(2 downto 0);
            REG_READ_ADDR_B   : out std_logic_vector(2 downto 0);
            REG_WRITE_ADDR    : out std_logic_vector(2 downto 0);
            REG_WRITE_EN      : out std_logic;
            SIZE_SEL_8_16     : out std_logic;
            ALU_OP_SEL        : out std_logic_vector(3 downto 0);
            ALU_IN_B_MUX_SEL  : out std_logic_vector(1 downto 0);
            FLAG_REG_WRITE_EN : out std_logic;
            IR_OUT            : out std_logic_vector(15 downto 0)
        );
    end component ControlUnit;

    component ALU16b is
        Port (
            ALU_OP_SEL   : in  std_logic_vector(3 downto 0);
            DATA_IN_A    : in  std_logic_vector(15 downto 0);
            DATA_IN_B    : in  std_logic_vector(15 downto 0);
            SHIFT_IMM    : in  std_logic_vector(4 downto 0);
            ALU_OUT      : out std_logic_vector(15 downto 0);
            FLAGS_OUT_16 : out std_logic_vector(3 downto 0);
            FLAGS_OUT_8  : out std_logic_vector(3 downto 0)
        );
    end component ALU16b;

    component RegFile is
        Port (
            CLK           : in  std_logic;
            RESET         : in  std_logic;
            SIZE_SEL      : in  std_logic;                     -- '0'=16-bit, '1'=8-bit
            WR_EN         : in  std_logic;
            ADDR_WR       : in  std_logic_vector(2 downto 0);  -- Logical Addr (000-111)
            DATA_WR       : in  std_logic_vector(15 downto 0);
            ADDR_RD_A     : in  std_logic_vector(2 downto 0);
            DATA_RD_A_16  : out std_logic_vector(15 downto 0);
            DATA_RD_A_8   : out std_logic_vector(7 downto 0);
            ADDR_RD_B     : in  std_logic_vector(2 downto 0);
            DATA_RD_B_16  : out std_logic_vector(15 downto 0);
            DATA_RD_B_8   : out std_logic_vector(7 downto 0);
            AX_OUT        : out std_logic_vector(15 downto 0);
            BX_OUT        : out std_logic_vector(15 downto 0);
            CX_OUT        : out std_logic_vector(15 downto 0);
            DX_OUT        : out std_logic_vector(15 downto 0)
        );
    end component RegFile;

    component FlagsRegister is
        Port (
            CLK           : in  std_logic;
            RST           : in  std_logic;
            FLAG_WRITE_EN : in  std_logic;
            FLAGS_IN      : in  std_logic_vector(3 downto 0); -- S,O,C,Z
            FLAGS_OUT     : out std_logic_vector(3 downto 0)
        );
    end component FlagsRegister;
    
    -- === Internal Signals ===
    -- (Control Signals)
    signal s_cu_fifo_read_en   : std_logic;
    signal s_cu_mem_write_en   : std_logic;
    signal s_cu_reg_read_a     : std_logic_vector(2 downto 0);
    signal s_cu_reg_read_b     : std_logic_vector(2 downto 0);
    signal s_cu_reg_write_addr : std_logic_vector(2 downto 0);
    signal s_cu_reg_write_en   : std_logic;
    signal s_cu_size_sel       : std_logic;
    signal s_cu_alu_op         : std_logic_vector(3 downto 0);
    signal s_cu_mux_b_sel      : std_logic_vector(1 downto 0);
    signal s_cu_flag_write_en  : std_logic;
    signal s_cu_ir             : std_logic_vector(15 downto 0);
    
    -- (RegFile Data Signals)
    signal s_reg_data_a_16 : std_logic_vector(15 downto 0);
    signal s_reg_data_a_8  : std_logic_vector(7 downto 0);
    signal s_reg_data_b_16 : std_logic_vector(15 downto 0);
    signal s_reg_data_b_8  : std_logic_vector(7 downto 0);
    
    -- (ALU Data Signals)
    signal s_alu_out       : std_logic_vector(15 downto 0);
    signal s_flags_out_16  : std_logic_vector(3 downto 0);
    signal s_flags_out_8   : std_logic_vector(3 downto 0);
    
    -- (FlagsRegister Data Signals)
    signal s_current_flags : std_logic_vector(3 downto 0);
    
    -- ("Extra Logic" Signals)
    signal s_alu_in_a           : std_logic_vector(15 downto 0);
    signal s_alu_in_b           : std_logic_vector(15 downto 0);
    signal s_extended_immediate : std_logic_vector(15 downto 0);
    signal s_shift_immediate    : std_logic_vector(4 downto 0);
    signal s_flags_to_reg       : std_logic_vector(3 downto 0);
    
    -- (Constants)
    constant MUX_B_REGS : std_logic_vector(1 downto 0) := "00";
    constant MUX_B_MEM  : std_logic_vector(1 downto 0) := "01";
    constant MUX_B_IMM  : std_logic_vector(1 downto 0) := "10";
    
    -- Internal signals to capture register values for output
    signal s_ax_val, s_bx_val, s_cx_val, s_dx_val : std_logic_vector(15 downto 0);
    
    signal s_reg_data_b_for_alu : std_logic_vector(15 downto 0);

begin

    -- Pass internal flags state to output port
    CURRENT_FLAGS_OUT <= s_current_flags;
    IR_OUT <= s_cu_ir;

    -- === Component Instantiations ===
    
        CCU : component ControlUnit
        port map (
            CLK               => CLK,
            RST               => RST,
            STEP_BUTTON_IN    => STEP_BUTTON_IN,
            INSTRUCTION_IN    => INSTRUCTION_IN,
            FIFO_EMPTY        => FIFO_EMPTY,
            MEM_DATA_IN       => MEM_DATA_IN,
            CURRENT_FLAGS     => s_current_flags,
            FIFO_READ_EN      => s_cu_fifo_read_en,
            DATA_OFFSET_OUT   => DATA_OFFSET_OUT,
            MEM_WRITE_EN      => s_cu_mem_write_en,
            BIU_JUMP_EN       => BIU_JUMP_EN,
            BIU_FLUSH         => BIU_FLUSH,
            BIU_JUMP_TARGET   => BIU_JUMP_TARGET,
            REG_READ_ADDR_A   => s_cu_reg_read_a,
            REG_READ_ADDR_B   => s_cu_reg_read_b,
            REG_WRITE_ADDR    => s_cu_reg_write_addr,
            REG_WRITE_EN      => s_cu_reg_write_en,
            SIZE_SEL_8_16     => s_cu_size_sel,
            ALU_OP_SEL        => s_cu_alu_op,
            ALU_IN_B_MUX_SEL  => s_cu_mux_b_sel,
            FLAG_REG_WRITE_EN => s_cu_flag_write_en,
            IR_OUT            => s_cu_ir
        );

        CRegFile : component RegFile
        port map (
            CLK           => CLK,
            RESET         => RST,
            SIZE_SEL      => s_cu_size_sel,        -- Connect 's' bit
            WR_EN         => s_cu_reg_write_en,
            ADDR_WR       => s_cu_reg_write_addr,  -- Pass logical addr
            DATA_WR       => s_alu_out,
            ADDR_RD_A     => s_cu_reg_read_a,      -- Pass logical addr
            DATA_RD_A_16  => s_reg_data_a_16,
            DATA_RD_A_8   => s_reg_data_a_8,
            ADDR_RD_B     => s_cu_reg_read_b,      -- Pass logical addr
            DATA_RD_B_16  => s_reg_data_b_16,
            DATA_RD_B_8   => s_reg_data_b_8,
            AX_OUT        => s_ax_val,
            BX_OUT        => s_bx_val,
            CX_OUT        => s_cx_val,
            DX_OUT        => s_dx_val
        );

        CALU : component ALU16b
        port map (
            ALU_OP_SEL   => s_cu_alu_op,
            DATA_IN_A    => s_alu_in_a,    
            DATA_IN_B    => s_alu_in_b,    
            SHIFT_IMM    => s_shift_immediate, 
            ALU_OUT      => s_alu_out,
            FLAGS_OUT_16 => s_flags_out_16,
            FLAGS_OUT_8  => s_flags_out_8
        );

        CFlags : component FlagsRegister
        port map (
            CLK           => CLK,
            RST           => RST,
            FLAG_WRITE_EN => s_cu_flag_write_en,
            FLAGS_IN      => s_flags_to_reg,      
            FLAGS_OUT     => s_current_flags      
        );

    FIFO_READ_EN   <= s_cu_fifo_read_en;
    MEM_WRITE_EN   <= s_cu_mem_write_en;
    
    -- MUX for ALU Input A 
    s_alu_in_a <= s_reg_data_a_16 when s_cu_size_sel = '0' else
                  ("00000000" & s_reg_data_a_8);
    
    -- Select 16-bit (AX) or 8-bit (AL/AH) data for memory writes (STD)
    MEM_DATA_OUT <= s_reg_data_a_16 when s_cu_size_sel = '0' else
                    "00000000" & s_reg_data_a_8;

    process(s_cu_ir)
        variable v_opcode : std_logic_vector(4 downto 0);
        variable v_imm7   : std_logic_vector(6 downto 0);
    begin
        v_opcode := s_cu_ir(15 downto 11);
        v_imm7   := s_cu_ir(6 downto 0);
        
        case v_opcode is
            when "00010" | "00111" => 
                s_extended_immediate <= std_logic_vector(resize(signed(v_imm7), 16));
            when others =>
                s_extended_immediate <= (others => '0');
        end case;
    end process;

    s_shift_immediate <= s_cu_ir(6 downto 2);
    
    

    -- MUX for ALU Input B (Regs path)
    s_reg_data_b_for_alu <= s_reg_data_b_16 when s_cu_size_sel = '0' else
                            ("00000000" & s_reg_data_b_8);

    -- Main MUX for ALU Input B
    with s_cu_mux_b_sel select
        s_alu_in_b <=
            s_reg_data_b_for_alu   when MUX_B_REGS,
            MEM_DATA_IN            when MUX_B_MEM,
            s_extended_immediate   when MUX_B_IMM,
            (others => '0')        when others;

    -- '1' = 8-bit, '0' = 16-bit
    s_flags_to_reg <= s_flags_out_8 when s_cu_size_sel = '1' else 
                      s_flags_out_16;
                      
    AX_OUT <= s_ax_val;
    BX_OUT <= s_bx_val;
    CX_OUT <= s_cx_val;
    DX_OUT <= s_dx_val;

end architecture Behavioral;



