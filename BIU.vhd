----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/19/2025 06:41:27 PM
-- Design Name: 
-- Module Name: BIU - Behavioral
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


entity BIU is
    Port (
        CLK                     : in  std_logic;
        RST                     : in  std_logic;

        -- === To/From Segmented_RAM ===
        -- Instruction Fetch Path
        INSTR_ADDR_OUT          : out std_logic_vector(19 downto 0); -- To RAM.INSTR_ADDR
        INSTR_DATA_IN           : in  std_logic_vector(15 downto 0); -- From RAM.INSTR_OUT
        
        -- Data Access Path (Pass-through from EU)
        DATA_ADDR_OUT           : out std_logic_vector(19 downto 0); -- To RAM.DATA_READ_ADDR
        DATA_READ_IN            : in  std_logic_vector(15 downto 0); -- From RAM.DATA_READ
        RAM_WRITE_EN_OUT        : out std_logic;                     -- To RAM.WRITE_EN
        RAM_WRITE_ADDR_OUT      : out std_logic_vector(19 downto 0); -- To RAM.DATA_WRITE_ADDR
        RAM_LOAD_DATA_OUT       : out std_logic_vector(15 downto 0); -- To RAM.LOAD_DATA
        
        -- === To/From Execution Unit (EU) / Control Unit (CU) ===
        -- Instruction Path
        INSTR_OUT_TO_EU         : out std_logic_vector(15 downto 0); -- From FIFO.INSTRUCTION_OUT
        FIFO_EMPTY_TO_EU        : out std_logic;                     -- From FIFO.EMPTY
        READ_EN_FROM_EU         : in  std_logic;                     -- To FIFO.READ_EN
        
        -- Jump/Flush Control
        FLUSH_FROM_EU           : in  std_logic;                     -- To FIFO.FLUSH
        JUMP_EN_FROM_EU         : in  std_logic;                     -- To AddrCalc.JUMP_EN
        TARGET_ADDR_FROM_EU     : in std_logic_vector(19 downto 0);  -- To AddrCalc.TARGET_ADDR_IN
        
        -- Data Access Path
        DATA_OFFSET_FROM_EU     : in  std_logic_vector(15 downto 0); -- To AddrCalc.DATA_OFFSET_IN
        DATA_READ_OUT_TO_EU     : out std_logic_vector(15 downto 0); -- Pass-through from RAM
        DATA_WRITE_EN_FROM_EU   : in  std_logic;                     -- Pass-through to RAM
        DATA_TO_WRITE_FROM_EU   : in  std_logic_vector(15 downto 0); -- Pass-through to RAM
        Q_OUT_0_FIFO            : out std_logic_vector(15 downto 0);
        Q_OUT_1_FIFO            : out std_logic_vector(15 downto 0);
        Q_OUT_2_FIFO            : out std_logic_vector(15 downto 0)   
    );
end entity BIU;

architecture Behavioral of BIU is

    -- === 1. Component Declarations ===
    component SegmentsReg is
        Port (
            CLK       : in  std_logic;
            RST       : in  std_logic;
            NEW_IP_IN : in  std_logic_vector(15 downto 0);
            CS_OUT    : out std_logic_vector(15 downto 0);
            IP_OUT    : out std_logic_vector(15 downto 0);
            DS_OUT    : out std_logic_vector(15 downto 0);
            SS_OUT    : out std_logic_vector(15 downto 0);
            ES_OUT    : out std_logic_vector(15 downto 0)
        );
    end component;
    
    component AddressCalculator is
        Port (
            CS_IN                       : in  std_logic_vector(15 downto 0);
            IP_IN                       : in  std_logic_vector(15 downto 0);
            DS_IN                       : in  std_logic_vector(15 downto 0);
            SS_IN                       : in  std_logic_vector(15 downto 0);
            ES_IN                       : in  std_logic_vector(15 downto 0);
            DATA_OFFSET_IN              : in  std_logic_vector(15 downto 0);
            JUMP_EN                     : in  std_logic;
            TARGET_ADDR_IN              : in  std_logic_vector(19 downto 0);
            INCREMENT_IP_EN             : in  std_logic;
            CURRENT_PHYSICAL_ADDR_OUT   : out std_logic_vector(19 downto 0);
            DATA_PHYSICAL_ADDR_OUT      : out std_logic_vector(19 downto 0);
            NEXT_IP_OUT                 : out std_logic_vector(15 downto 0)
        );
    end component;

    component FIFO is
        Port (
            CLK             : in  std_logic;
            RST             : in  std_logic;
            WRITE_EN        : in  std_logic;
            READ_EN         : in  std_logic;
            FLUSH           : in  std_logic;
            INSTRUCTION_IN  : in  std_logic_vector(15 downto 0);
            INSTRUCTION_OUT : out std_logic_vector(15 downto 0);
            FULL            : out std_logic;
            EMPTY           : out std_logic;
            Q_OUT_0         : out std_logic_vector(15 downto 0);
            Q_OUT_1         : out std_logic_vector(15 downto 0);
            Q_OUT_2         : out std_logic_vector(15 downto 0)
        );
    end component;

    -- === 2. Internal Signals ===
    
    -- Wires from SegmentsReg to AddressCalculator
    signal s_cs_out : std_logic_vector(15 downto 0);
    signal s_ip_out : std_logic_vector(15 downto 0);
    signal s_ds_out : std_logic_vector(15 downto 0);
    signal s_ss_out : std_logic_vector(15 downto 0);
    signal s_es_out : std_logic_vector(15 downto 0);
    
    -- Wires from AddressCalculator
    signal s_next_ip_in          : std_logic_vector(15 downto 0); -- To SegmentsReg
    signal s_instr_addr_out      : std_logic_vector(19 downto 0); -- To RAM
    signal s_data_read_addr_out  : std_logic_vector(19 downto 0); -- To RAM
    signal s_data_write_addr_out : std_logic_vector(19 downto 0); -- To RAM
    
    -- Wires from FIFO
    signal s_fifo_full     : std_logic;
    signal s_fifo_empty    : std_logic;
    
    -- Wire for the BIU Controller
    signal s_fifo_write_en : std_logic; -- From BIU Controller to FIFO

    -- === 3. BIU Control State Machine ===
    type t_biu_state is (IDLE, FETCH_WAIT_1, FETCH_WRITE);
    signal biu_state : t_biu_state := IDLE;

    signal s_increment_ip_en : std_logic := '0';
       
    signal s_q_out_0_fifo : std_logic_vector(15 downto 0);
    signal s_q_out_1_fifo : std_logic_vector(15 downto 0);
    signal s_q_out_2_fifo : std_logic_vector(15 downto 0);

begin

    -- === 4. Component Instantiation  ===

    CSegmentsReg : component SegmentsReg
        port map (
            CLK       => CLK,
            RST       => RST,
            NEW_IP_IN => s_next_ip_in,
            CS_OUT    => s_cs_out,
            IP_OUT    => s_ip_out,
            DS_OUT    => s_ds_out,
            SS_OUT    => s_ss_out,
            ES_OUT    => s_es_out
        );

    CAddrCalc : component AddressCalculator
        port map (
            CS_IN                     => s_cs_out,
            IP_IN                     => s_ip_out,
            DS_IN                     => s_ds_out,
            SS_IN                     => s_ss_out,
            ES_IN                     => s_es_out,
            DATA_OFFSET_IN            => DATA_OFFSET_FROM_EU,
            JUMP_EN                   => JUMP_EN_FROM_EU,
            TARGET_ADDR_IN            => TARGET_ADDR_FROM_EU,
            INCREMENT_IP_EN           => s_increment_ip_en,
            CURRENT_PHYSICAL_ADDR_OUT => s_instr_addr_out,
            DATA_PHYSICAL_ADDR_OUT    => s_data_read_addr_out,
            NEXT_IP_OUT               => s_next_ip_in
        );

    CFIFO : component FIFO
        port map (
            CLK             => CLK,
            RST             => rst,
            WRITE_EN        => s_fifo_write_en, 
            READ_EN         => READ_EN_FROM_EU, 
            FLUSH           => FLUSH_FROM_EU,   
            INSTRUCTION_IN  => INSTR_DATA_IN,   
            INSTRUCTION_OUT => INSTR_OUT_TO_EU, 
            FULL            => s_fifo_full,
            EMPTY           => s_fifo_empty,
            Q_OUT_0         => s_q_out_0_fifo,
            Q_OUT_1         => s_q_out_1_fifo,
            Q_OUT_2         => s_q_out_2_fifo
        );


    -- === 5. Combinational Wiring and Pass-through Logic ===
    
    -- Connect internal signals to the BIU's output ports
    INSTR_ADDR_OUT   <= s_instr_addr_out;
    FIFO_EMPTY_TO_EU <= s_fifo_empty;
    
    -- Pass-through logic for EU data access
    DATA_ADDR_OUT       <= s_data_read_addr_out; 
    DATA_READ_OUT_TO_EU <= DATA_READ_IN;         
    
    -- Pass-through logic for EU data writes
    RAM_WRITE_EN_OUT  <= DATA_WRITE_EN_FROM_EU; 
    RAM_LOAD_DATA_OUT <= DATA_TO_WRITE_FROM_EU; 
    RAM_WRITE_ADDR_OUT <= s_data_read_addr_out; 
    
    
    -- === 6. Implementation (State Machine Process) ===

BIU_Controller_Process: process (CLK, RST)
    begin
        if rst = '1' then
            biu_state            <= IDLE;
            s_fifo_write_en      <= '0';
            s_increment_ip_en    <= '0'; 
        elsif rising_edge(CLK) then
            s_fifo_write_en    <= '0';
            s_increment_ip_en <= '0';
            if FLUSH_FROM_EU = '1' then
                        biu_state            <= IDLE;
                        s_fifo_write_en      <= '0';
                        s_increment_ip_en    <= '0'; 
                    else
                        case biu_state is
                            when IDLE =>
                              if (s_fifo_full = '0') and (s_fifo_write_en = '0') then
                                biu_state <= FETCH_WAIT_1;
                              end if;
                                
                            when FETCH_WAIT_1 =>
                                -- Wait one cycle for RAM to get the address
                                biu_state <= FETCH_WRITE;
                                
                            when FETCH_WRITE =>
                                -- The data from RAM is now valid.
                                -- Trigger the FIFO write and the IP increment
                                s_fifo_write_en    <= '1';
                                s_increment_ip_en  <= '1';
                                biu_state          <= IDLE; 
                                
                        end case;
                    end if;
                end if;
            end process BIU_Controller_Process;

    Q_OUT_0_FIFO <= s_q_out_0_fifo;
    Q_OUT_1_FIFO <= s_q_out_1_fifo;
    Q_OUT_2_FIFO <= s_q_out_2_fifo;

end architecture Behavioral;


