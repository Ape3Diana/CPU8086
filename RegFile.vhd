----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/19/2025 06:02:02 PM
-- Design Name: 
-- Module Name: RegFile - Behavioral
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

entity RegFile is
    Port (
        CLK           : in  std_logic;
        RESET         : in  std_logic;

        -- Unified Size Select
        SIZE_SEL      : in  std_logic;                     -- '0'=16-bit, '1'=8-bit

        -- Write Port
        WR_EN         : in  std_logic;
        ADDR_WR       : in  std_logic_vector(2 downto 0);  -- Logical Addr (000-111)
        DATA_WR       : in  std_logic_vector(15 downto 0);
        
        -- Read Port A
        ADDR_RD_A     : in  std_logic_vector(2 downto 0);
        DATA_RD_A_16  : out std_logic_vector(15 downto 0);
        DATA_RD_A_8   : out std_logic_vector(7 downto 0);

        -- Read Port B
        ADDR_RD_B     : in  std_logic_vector(2 downto 0);
        DATA_RD_B_16  : out std_logic_vector(15 downto 0);
        DATA_RD_B_8   : out std_logic_vector(7 downto 0);

        -- Monitoring Outputs
        AX_OUT        : out std_logic_vector(15 downto 0);
        BX_OUT        : out std_logic_vector(15 downto 0);
        CX_OUT        : out std_logic_vector(15 downto 0);
        DX_OUT        : out std_logic_vector(15 downto 0)
    );
end entity RegFile;

architecture Behavioral of RegFile is

    -- Internal Register Signals
    signal AX_REG : std_logic_vector(15 downto 0) := (others => '0');
    signal BX_REG : std_logic_vector(15 downto 0) := (others => '0');
    signal CX_REG : std_logic_vector(15 downto 0) := (others => '0');
    signal DX_REG : std_logic_vector(15 downto 0) := (others => '0');
    signal SP_REG : std_logic_vector(15 downto 0) := (others => '0');
    signal BP_REG : std_logic_vector(15 downto 0) := (others => '0');
    signal SI_REG : std_logic_vector(15 downto 0) := (others => '0');
    signal DI_REG : std_logic_vector(15 downto 0) := (others => '0');

    -- Internal signals for 8-bit read logic
    signal s_rd_a_phys_addr : std_logic_vector(1 downto 0);
    signal s_rd_a_8_low, s_rd_a_8_high : std_logic_vector(7 downto 0);
    
    signal s_rd_b_phys_addr : std_logic_vector(1 downto 0);
    signal s_rd_b_8_low, s_rd_b_8_high : std_logic_vector(7 downto 0);

begin


    -- === 1. Synchronous Write Process ===

    Write_Process: process (CLK, RESET)
    begin
        if RESET = '1' then
            AX_REG <= (others => '0'); BX_REG <= (others => '0');
            CX_REG <= (others => '0'); DX_REG <= (others => '0');
            SP_REG <= (others => '0'); BP_REG <= (others => '0');
            SI_REG <= (others => '0'); DI_REG <= (others => '0');
        elsif rising_edge(CLK) then
            if WR_EN = '1' then
                if SIZE_SEL = '0' then
                    -- 16-bit write
                    case ADDR_WR is
                        when "000" => AX_REG <= DATA_WR;
                        when "001" => BX_REG <= DATA_WR;
                        when "010" => CX_REG <= DATA_WR;
                        when "011" => DX_REG <= DATA_WR;
                        when "100" => SP_REG <= DATA_WR;
                        when "101" => BP_REG <= DATA_WR;
                        when "110" => SI_REG <= DATA_WR;
                        when "111" => DI_REG <= DATA_WR;
                        when others => null;
                    end case;
                else
                    -- 8-bit write
                    case ADDR_WR(2 downto 1) is
                        when "00" => -- AX
                            if ADDR_WR(0) = '1' then -- Low byte (001)
                                AX_REG(7 downto 0) <= DATA_WR(7 downto 0);
                            else -- High byte (000)
                                AX_REG(15 downto 8) <= DATA_WR(7 downto 0);
                            end if;
                        when "01" => -- BX
                            if ADDR_WR(0) = '1' then -- Low byte (011)
                                BX_REG(7 downto 0) <= DATA_WR(7 downto 0);
                            else -- High byte (010)
                                BX_REG(15 downto 8) <= DATA_WR(7 downto 0);
                            end if;
                        when "10" => -- CX
                            if ADDR_WR(0) = '1' then -- Low byte (101)
                                CX_REG(7 downto 0) <= DATA_WR(7 downto 0);
                            else -- High byte (100)
                                CX_REG(15 downto 8) <= DATA_WR(7 downto 0);
                            end if;
                        when "11" => -- DX
                            if ADDR_WR(0) = '1' then -- Low byte (111)
                                DX_REG(7 downto 0) <= DATA_WR(7 downto 0);
                            else -- High byte (110)
                                DX_REG(15 downto 8) <= DATA_WR(7 downto 0);
                            end if;
                        when others => null;
                    end case;
                end if;
            end if;
        end if;
    end process Write_Process;


    -- === 2. Combinational Read Ports ===

    -- === Read Port A ===
    
    -- 16-bit Read
    with ADDR_RD_A select
        DATA_RD_A_16 <= AX_REG when "000",
                        BX_REG when "001",
                        CX_REG when "010",
                        DX_REG when "011",
                        SP_REG when "100",
                        BP_REG when "101",
                        SI_REG when "110",
                        DI_REG when "111",
                        (others => '0') when others;

    -- 8-bit Read Logic
    s_rd_a_phys_addr <= ADDR_RD_A(2 downto 1);

    -- Internal 8-bit LOW Read
    with s_rd_a_phys_addr select
        s_rd_a_8_low <= AX_REG(7 downto 0) when "00",
                        BX_REG(7 downto 0) when "01",
                        CX_REG(7 downto 0) when "10",
                        DX_REG(7 downto 0) when "11",
                        (others => '0') when others;

    -- Internal 8-bit HIGH Read
    with s_rd_a_phys_addr select
        s_rd_a_8_high <= AX_REG(15 downto 8) when "00",
                         BX_REG(15 downto 8) when "01",
                         CX_REG(15 downto 8) when "10",
                         DX_REG(15 downto 8) when "11",
                         (others => '0') when others;

    DATA_RD_A_8 <= s_rd_a_8_high when (SIZE_SEL = '1' and ADDR_RD_A(0) = '0') else -- 8-bit, High Byte
                   s_rd_a_8_low  when (SIZE_SEL = '1' and ADDR_RD_A(0) = '1') else -- 8-bit, Low Byte
                   (others => 'X');

    -- === Read Port B (Repeat logic) ===
    
    -- 16-bit Read
    with ADDR_RD_B select
        DATA_RD_B_16 <= AX_REG when "000",
                        BX_REG when "001",
                        CX_REG when "010",
                        DX_REG when "011",
                        SP_REG when "100",
                        BP_REG when "101",
                        SI_REG when "110",
                        DI_REG when "111",
                        (others => '0') when others;

    -- 8-bit Read Logic
    s_rd_b_phys_addr <= ADDR_RD_B(2 downto 1);
    
    -- Internal 8-bit LOW Read
    with s_rd_b_phys_addr select
        s_rd_b_8_low <= AX_REG(7 downto 0) when "00",
                        BX_REG(7 downto 0) when "01",
                        CX_REG(7 downto 0) when "10",
                        DX_REG(7 downto 0) when "11",
                        (others => '0') when others;

    -- Internal 8-bit HIGH Read
    with s_rd_b_phys_addr select
        s_rd_b_8_high <= AX_REG(15 downto 8) when "00",
                         BX_REG(15 downto 8) when "01",
                         CX_REG(15 downto 8) when "10",
                         DX_REG(15 downto 8) when "11",
                         (others => '0') when others;

    DATA_RD_B_8 <= s_rd_b_8_high when (SIZE_SEL = '1' and ADDR_RD_B(0) = '0') else -- 8-bit, High Byte
                   s_rd_b_8_low  when (SIZE_SEL = '1' and ADDR_RD_B(0) = '1') else -- 8-bit, Low Byte
                   (others => 'X');

    -- 3. Direct Register Outputs (Unchanged)
    AX_OUT <= AX_REG;
    BX_OUT <= BX_REG;
    CX_OUT <= CX_REG;
    DX_OUT <= DX_REG;

end architecture Behavioral;

