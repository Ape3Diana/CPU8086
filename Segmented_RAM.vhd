----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/19/2025 04:29:23 PM
-- Design Name: 
-- Module Name: Segmented_RAM - Behavioral
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

use IEEE.numeric_std.all;

entity Segmented_RAM is
    Port (
        CLK             : in  std_logic;                                
        RST             : in  std_logic;                                 

        -- Port I: Instruction Read (Synchronous)
        INSTR_ADDR      : in  std_logic_vector(19 downto 0);             -- 20-bit Byte Address for Instruction Fetch
        INSTR_OUT       : out std_logic_vector(15 downto 0);             -- 16-bit Instruction Read (Latched)

        -- Port R: Data Read (Asynchronous/Continuous)
        DATA_READ_ADDR  : in  std_logic_vector(19 downto 0);             -- 20-bit Byte Address for Data Read
        DATA_READ       : out std_logic_vector(15 downto 0);             -- 16-bit Data Read (Continuous)

        -- Port W: Data Write (Synchronous)
        DATA_WRITE_ADDR : in  std_logic_vector(19 downto 0);             -- 20-bit Byte Address for Data Write
        WRITE_EN        : in  std_logic;                                 -- Write Enable Signal (Synchronous)
        LOAD_DATA       : in  std_logic_vector(15 downto 0)              -- 16-bit data to write
    );
end entity Segmented_RAM;

architecture Behavioral of Segmented_RAM is

    -- RAM Definition Constants -- MODIFIED SIZE --
    constant WORD_WIDTH      : integer := 16;
    constant CODE_WORDS      : integer := 256; -- Allocate 256 words for code
    constant DATA_WORDS      : integer := 256; -- Allocate 256 words for data
    constant STACK_WORDS     : integer := 1;   -- Allocate 1 word for stack
    constant EXTRA_WORDS     : integer := 1;   -- Allocate 1 word for extra
    constant RAM_SIZE_WORDS  : integer := CODE_WORDS + DATA_WORDS + STACK_WORDS + EXTRA_WORDS; -- Total = 514 words
    constant MAX_INDEX       : integer := RAM_SIZE_WORDS - 1;  -- 513
    
    -- Segment Start Indices (Word Indices) -- NEW --
    constant CODE_SEG_START_INDEX  : integer := 0;
    constant DATA_SEG_START_INDEX  : integer := CODE_SEG_START_INDEX + CODE_WORDS;  -- Starts at 256 (0x100)
    constant STACK_SEG_START_INDEX : integer := DATA_SEG_START_INDEX + DATA_WORDS;  -- Starts at 512 (0x200)
    constant EXTRA_SEG_START_INDEX : integer := STACK_SEG_START_INDEX + STACK_WORDS; -- Starts at 513 (0x201)
    
    -- Internal Memory Type
    type RAM_ARRAY_T is array (0 to MAX_INDEX) of std_logic_vector(WORD_WIDTH-1 downto 0);

    -- Initialization function for the RAM
    impure function InitRam return RAM_ARRAY_T is
        variable TempRam : RAM_ARRAY_T := (others => (others => '0'));
    begin
        -- Initialize Code Segment Area starting at index 0 (Physical Addr 00000h)
        
        TempRam(CODE_SEG_START_INDEX + 0) := X"3831"; -- LIR AX, 49 //16b -> s=0
        TempRam(CODE_SEG_START_INDEX + 1) := X"3D8C"; -- LIR BL, 12 //8b -> s=1
        TempRam(CODE_SEG_START_INDEX + 2) := X"3904"; -- LIR CX, 4 //16b ->s=0
        TempRam(CODE_SEG_START_INDEX + 3) := X"3F02"; -- LIR DH, 2 //8b -> s=1
        TempRam(CODE_SEG_START_INDEX + 4) := X"1980"; -- INC DX //16b -> s=0
        TempRam(CODE_SEG_START_INDEX + 5) := X"2400"; -- DEC AH //8b -> s=1
        TempRam(CODE_SEG_START_INDEX + 6) := X"1002"; -- ADI AX, 2 //16b ->s=0
        TempRam(CODE_SEG_START_INDEX + 7) := X"0184"; -- ADD DX, CX //16b -> s=0
        TempRam(CODE_SEG_START_INDEX + 8) := X"0804"; -- SUB AX,CX //16b -> s=0
        TempRam(CODE_SEG_START_INDEX + 9) := X"4800"; -- STD AX, 0 
        TempRam(CODE_SEG_START_INDEX + 10) := X"4080"; -- LDR BX, 0
        TempRam(CODE_SEG_START_INDEX + 11) := X"5420"; -- AND AH, BH
        TempRam(CODE_SEG_START_INDEX + 12) := X"5C10"; -- OR AH, AL
        TempRam(CODE_SEG_START_INDEX + 13) := X"6010"; -- XOR AX, BX
        TempRam(CODE_SEG_START_INDEX + 14) := X"6D00"; -- NOT BH
        TempRam(CODE_SEG_START_INDEX + 15) := X"6900"; -- NOT CX
        TempRam(CODE_SEG_START_INDEX + 16) := X"7190"; -- SHL DX, 4
        TempRam(CODE_SEG_START_INDEX + 17) := X"7F08"; -- SHR DH, 2
        TempRam(CODE_SEG_START_INDEX + 18) := X"9800"; -- NOOP
        TempRam(CODE_SEG_START_INDEX + 19) := X"3802"; -- LIR AX, 2
        TempRam(CODE_SEG_START_INDEX + 20) := X"3880"; -- LIR BX, 0
        TempRam(CODE_SEG_START_INDEX + 21) := X"1880"; -- INC BX
        TempRam(CODE_SEG_START_INDEX + 22) := X"2810"; -- CMP AX, BX
        TempRam(CODE_SEG_START_INDEX + 23) := X"9015"; -- JNZ, 21
        TempRam(CODE_SEG_START_INDEX + 24) := X"3C03"; -- LIR AH, 3
        TempRam(CODE_SEG_START_INDEX + 25) := X"3C84"; -- LIR AL, 4
        TempRam(CODE_SEG_START_INDEX + 26) := X"2480"; -- DEC AL
        TempRam(CODE_SEG_START_INDEX + 27) := X"2C10"; -- CMP AH, AL
        TempRam(CODE_SEG_START_INDEX + 28) := X"881A"; -- JZ, 26
        TempRam(CODE_SEG_START_INDEX + 29) := X"0001"; -- ADD AX, 0
        TempRam(CODE_SEG_START_INDEX + 30) := X"3010"; -- MOV AX, BX
        TempRam(CODE_SEG_START_INDEX + 31) := X"8000"; -- JMP 0
        
        return TempRam;
    end function InitRam;

    -- Internal RAM Signal initialized by the function
    signal MEMORY : RAM_ARRAY_T := InitRam;

    -- Internal signals for indices
    signal RAM_INDEX_INSTR : integer range 0 to MAX_INDEX;
    signal RAM_INDEX_READ  : integer range 0 to MAX_INDEX;
    signal RAM_INDEX_WRITE : integer range 0 to MAX_INDEX;

    -- Internal register for instruction output
    signal INSTR_OUT_REG   : std_logic_vector(15 downto 0) := (others => '0');

begin

    -- Address Decoder 
    RAM_Index_Conversion: process (INSTR_ADDR, DATA_READ_ADDR, DATA_WRITE_ADDR)
    begin
        -- Check if address is within bounds before converting
        -- Instruction Address
        if to_integer(unsigned(INSTR_ADDR(19 downto 1))) <= MAX_INDEX then
            RAM_INDEX_INSTR <= to_integer(unsigned(INSTR_ADDR(19 downto 1)));
        else 
            RAM_INDEX_INSTR <= 0; -- Default or error index
        end if;
        
        -- Data Read Address
        if to_integer(unsigned(DATA_READ_ADDR(19 downto 1))) <= MAX_INDEX then
             RAM_INDEX_READ  <= to_integer(unsigned(DATA_READ_ADDR(19 downto 1)));
        else 
            RAM_INDEX_READ <= 0; -- Default or error index
        end if;
        
        -- Data Write Address
        if to_integer(unsigned(DATA_WRITE_ADDR(19 downto 1))) <= MAX_INDEX then
            RAM_INDEX_WRITE <= to_integer(unsigned(DATA_WRITE_ADDR(19 downto 1)));
        else
             RAM_INDEX_WRITE <= 0; -- Default or error index
        end if;
    end process RAM_Index_Conversion;


    -- Synchronous Memory Access Process 
    RAM_Access_Process: process (CLK)
    begin
        if rising_edge(CLK) then
            if rst = '1' then
                 INSTR_OUT_REG <= (others => '0'); 
            else
                 -- Write Operation (Check index bounds)
                if WRITE_EN = '1' and RAM_INDEX_WRITE <= MAX_INDEX then
                    MEMORY(RAM_INDEX_WRITE) <= LOAD_DATA;
                end if;

                -- Instruction Read Operation (Check index bounds)
                if RAM_INDEX_INSTR <= MAX_INDEX then
                    INSTR_OUT_REG <= MEMORY(RAM_INDEX_INSTR);
                else 
                    INSTR_OUT_REG <= (others => 'X'); -- Indicate invalid read
                end if;

            end if;
        end if;
    end process RAM_Access_Process;

    -- Output drivers (Data Read checks index bounds)
    INSTR_OUT <= INSTR_OUT_REG;
    
    -- Combinational Data Read (Check index bounds)
    process(RAM_INDEX_READ)
    begin
        if RAM_INDEX_READ <= MAX_INDEX then
            DATA_READ <= MEMORY(RAM_INDEX_READ);
        else
            DATA_READ <= (others => 'X'); -- Indicate invalid read
        end if;
    end process;
 
end architecture Behavioral;
