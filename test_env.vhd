----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/19/2025 08:14:26 PM
-- Design Name: 
-- Module Name: test_env - Behavioral
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

entity test_env is
    Port ( clk : in STD_LOGIC;
           btn : in STD_LOGIC_VECTOR (4 downto 0);
           sw : in STD_LOGIC_VECTOR (15 downto 0);
           led : out STD_LOGIC_VECTOR (15 downto 0);
           an : out STD_LOGIC_VECTOR (7 downto 0);
           cat : out STD_LOGIC_VECTOR (6 downto 0)
);
end test_env;

architecture Behavioral of test_env is

    -- === 1. Component Declarations ===
    component BIU is
        Port (
            CLK                     : in  std_logic;
            RST                     : in  std_logic;
            INSTR_ADDR_OUT          : out std_logic_vector(19 downto 0);
            INSTR_DATA_IN           : in  std_logic_vector(15 downto 0);
            DATA_ADDR_OUT           : out std_logic_vector(19 downto 0);
            DATA_READ_IN            : in  std_logic_vector(15 downto 0);
            RAM_WRITE_EN_OUT        : out std_logic;
            RAM_WRITE_ADDR_OUT      : out std_logic_vector(19 downto 0);
            RAM_LOAD_DATA_OUT       : out std_logic_vector(15 downto 0);
            INSTR_OUT_TO_EU         : out std_logic_vector(15 downto 0);
            FIFO_EMPTY_TO_EU        : out std_logic;
            READ_EN_FROM_EU         : in  std_logic;
            FLUSH_FROM_EU           : in  std_logic;
            JUMP_EN_FROM_EU         : in  std_logic;
            TARGET_ADDR_FROM_EU     : in  std_logic_vector(19 downto 0);
            DATA_OFFSET_FROM_EU     : in  std_logic_vector(15 downto 0);
            DATA_READ_OUT_TO_EU     : out std_logic_vector(15 downto 0);
            DATA_WRITE_EN_FROM_EU   : in  std_logic;
            DATA_TO_WRITE_FROM_EU   : in  std_logic_vector(15 downto 0);
            Q_OUT_0_FIFO            :out std_logic_vector(15 downto 0);
            Q_OUT_1_FIFO            :out std_logic_vector(15 downto 0);
            Q_OUT_2_FIFO            :out std_logic_vector(15 downto 0)
        );
    end component BIU;

    component EU is
        Port (
            CLK               : in  std_logic;
            RST               : in  std_logic;
            STEP_BUTTON_IN    : in  std_logic;
            INSTRUCTION_IN    : in  std_logic_vector(15 downto 0);
            FIFO_EMPTY        : in  std_logic;
            MEM_DATA_IN       : in  std_logic_vector(15 downto 0);
            FIFO_READ_EN      : out std_logic;
            DATA_OFFSET_OUT   : out std_logic_vector(15 downto 0);
            BIU_JUMP_EN       : out std_logic;
            BIU_FLUSH         : out std_logic;
            BIU_JUMP_TARGET   : out std_logic_vector(19 downto 0);
            MEM_WRITE_EN      : out std_logic;
            MEM_DATA_OUT      : out std_logic_vector(15 downto 0);
            AX_OUT            : out std_logic_vector(15 downto 0);
            BX_OUT            : out std_logic_vector(15 downto 0);
            CX_OUT            : out std_logic_vector(15 downto 0);
            DX_OUT            : out std_logic_vector(15 downto 0);
            CURRENT_FLAGS_OUT : out std_logic_vector(3 downto 0);
            IR_OUT            : out std_logic_vector(15 downto 0)
        );
    end component EU;

    component Segmented_RAM is
        Port (
            CLK             : in  std_logic;
            RST             : in  std_logic;
            INSTR_ADDR      : in  std_logic_vector(19 downto 0);
            INSTR_OUT       : out std_logic_vector(15 downto 0);
            DATA_READ_ADDR  : in  std_logic_vector(19 downto 0);
            DATA_READ       : out std_logic_vector(15 downto 0);
            DATA_WRITE_ADDR : in  std_logic_vector(19 downto 0);
            WRITE_EN        : in  std_logic;
            LOAD_DATA       : in  std_logic_vector(15 downto 0)
        );
    end component Segmented_RAM;

    component MPG is
        Port ( 
            enable : out STD_LOGIC;
            btn    : in  STD_LOGIC;
            clk    : in  STD_LOGIC
        );
    end component MPG;

    component SSD is
        Port ( 
            clk    : in  STD_LOGIC;
            digits : in  STD_LOGIC_VECTOR(15 downto 0);
            an     : out STD_LOGIC_VECTOR(7 downto 0);
            cat    : out STD_LOGIC_VECTOR(6 downto 0)
        );
    end component SSD;

    -- === 2. Internal Signals ===
    
    signal s_clk          : std_logic;
    signal s_cpu_reset    : std_logic;
    signal s_btn_step     : std_logic; 
    signal s_step_pulse   : std_logic;
    
    signal s_instr_addr : std_logic_vector(19 downto 0);
    signal s_instr_data : std_logic_vector(15 downto 0);
    signal s_data_addr  : std_logic_vector(19 downto 0);
    signal s_data_read  : std_logic_vector(15 downto 0);
    signal s_ram_write_en : std_logic;
    signal s_ram_write_addr : std_logic_vector(19 downto 0);
    signal s_ram_load_data : std_logic_vector(15 downto 0);
    signal s_instr_to_eu   : std_logic_vector(15 downto 0); 
    signal s_fifo_empty    : std_logic;
    signal s_fifo_read_en  : std_logic;
    signal s_flush         : std_logic;
    signal s_jump_en       : std_logic;
    signal s_jump_target   : std_logic_vector(19 downto 0);
    signal s_data_offset   : std_logic_vector(15 downto 0);
    signal s_data_to_eu    : std_logic_vector(15 downto 0); 
    signal s_mem_write_en  : std_logic;                     
    signal s_mem_data_from_eu : std_logic_vector(15 downto 0); 
    signal s_ax_out, s_bx_out, s_cx_out, s_dx_out : std_logic_vector(15 downto 0);
    signal s_current_flags : std_logic_vector(3 downto 0); 
    
    signal s_ssd_digits : std_logic_vector(15 downto 0);
    
    signal s_cu_ir       : std_logic_vector(15 downto 0);
    
    signal s_q_out_0_fifo : std_logic_vector(15 downto 0);
    signal s_q_out_1_fifo : std_logic_vector(15 downto 0);
    signal s_q_out_2_fifo : std_logic_vector(15 downto 0);

begin

    s_clk <= clk; 
    s_cpu_reset <= btn(1); 
    s_btn_step  <= btn(0); 

    -- === 3. Component Instantiations ===

    MPG_Inst : component MPG
        port map ( enable => s_step_pulse, 
                   btn => s_btn_step, 
                   clk => s_clk );

        CBIU : component BIU
        port map (
            CLK                     => s_clk,
            RST                     => s_cpu_reset,
            INSTR_ADDR_OUT          => s_instr_addr,    
            INSTR_DATA_IN           => s_instr_data,
            DATA_ADDR_OUT           => s_data_addr,     
            DATA_READ_IN            => s_data_read,
            RAM_WRITE_EN_OUT        => s_ram_write_en,  
            RAM_WRITE_ADDR_OUT      => s_ram_write_addr,
            RAM_LOAD_DATA_OUT       => s_ram_load_data, 
            INSTR_OUT_TO_EU         => s_instr_to_eu,
            FIFO_EMPTY_TO_EU        => s_fifo_empty,    
            READ_EN_FROM_EU         => s_fifo_read_en,
            FLUSH_FROM_EU           => s_flush,         
            JUMP_EN_FROM_EU         => s_jump_en,
            TARGET_ADDR_FROM_EU     => s_jump_target,   
            DATA_OFFSET_FROM_EU     => s_data_offset,
            DATA_READ_OUT_TO_EU     => s_data_to_eu,    
            DATA_WRITE_EN_FROM_EU   => s_mem_write_en,
            DATA_TO_WRITE_FROM_EU   => s_mem_data_from_eu, 
            q_out_0_fifo            => s_q_out_0_fifo,
            q_out_1_fifo            => s_q_out_1_fifo, 
            q_out_2_fifo            => s_q_out_2_fifo
        );

        CEU : component EU
        port map (
            CLK               => s_clk,             
            RST               => s_cpu_reset,
            STEP_BUTTON_IN    => s_step_pulse,      
            INSTRUCTION_IN    => s_instr_to_eu,
            FIFO_EMPTY        => s_fifo_empty,      
            MEM_DATA_IN       => s_data_to_eu,
            FIFO_READ_EN      => s_fifo_read_en,    
            DATA_OFFSET_OUT   => s_data_offset,
            BIU_JUMP_EN       => s_jump_en,         
            BIU_FLUSH         => s_flush,
            BIU_JUMP_TARGET   => s_jump_target,     
            MEM_WRITE_EN      => s_mem_write_en,
            MEM_DATA_OUT      => s_mem_data_from_eu, 
            AX_OUT            => s_ax_out,
            BX_OUT            => s_bx_out,          
            CX_OUT            => s_cx_out,
            DX_OUT            => s_dx_out,          
            CURRENT_FLAGS_OUT => s_current_flags,
            IR_OUT            => s_cu_ir
        );

        CRAM : component Segmented_RAM
        port map (
            CLK             => s_clk,           
            RST             => s_cpu_reset,
            INSTR_ADDR      => s_instr_addr,    
            INSTR_OUT       => s_instr_data,
            DATA_READ_ADDR  => s_data_addr,     
            DATA_READ       => s_data_read,
            DATA_WRITE_ADDR => s_ram_write_addr, 
            WRITE_EN        => s_ram_write_en,
            LOAD_DATA       => s_ram_load_data
        );

        CSSD : component SSD
        port map ( clk => s_clk, 
                digits => s_ssd_digits, 
                    an => an, cat => cat ); 

    -- === 4. SSD Display Formatting Logic with MUX ===
    
    SSD_Format_Process: process(sw, s_instr_to_eu, s_current_flags, s_ax_out, s_bx_out, s_cx_out, s_dx_out) 
        variable v_flags_display : std_logic_vector(15 downto 0); 
    begin
        -- Format Flags for display (S O C Z as 0/1 on lowest 4 hex digits)
        v_flags_display := (others => '0');
        v_flags_display(15 downto 12) := "000" & s_current_flags(3); -- S
        v_flags_display(11 downto  8) := "000" & s_current_flags(2); -- O
        v_flags_display( 7 downto  4) := "000" & s_current_flags(1); -- C
        v_flags_display( 3 downto  0) := "000" & s_current_flags(0); -- Z

       case sw(3 downto 0) is
            when "0000"   => s_ssd_digits <= s_instr_to_eu;   -- next instruction to be loaded in CU
            when "0001"   => s_ssd_digits <= s_cu_ir;         -- instruction in execution
            when "0010"   => s_ssd_digits <= v_flags_display; -- Flags
            when "0011"   => s_ssd_digits <= s_ax_out;        -- AX Register
            when "0100"   => s_ssd_digits <= s_bx_out;        -- BX Register
            when "0101"   => s_ssd_digits <= s_cx_out;        -- CX Register
            when "0110"   => s_ssd_digits <= s_dx_out;        -- DX Register
            when "0111"   => s_ssd_digits <= s_q_out_0_fifo;  -- FIFO(0)
            when "1000"   => s_ssd_digits <= s_q_out_1_fifo;  -- FIFO(1)
            when "1001"   => s_ssd_digits <= s_q_out_2_fifo;  -- FIFO(2)
            when others  => s_ssd_digits <= s_instr_to_eu;   
        end case;
        
        -- === 5. NEW: Drive the LED Output Port ===
        -- flags S O C Z on led(3 downto 0)
        led(3 downto 0) <= s_current_flags;
        led(15 downto 4) <= (others => '0');
        
    end process SSD_Format_Process;

end architecture Behavioral;
