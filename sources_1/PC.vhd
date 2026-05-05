library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity PC is
    Port (
        CLK     : in  STD_LOGIC;
        RESET   : in  STD_LOGIC;
        ENABLE  : in  STD_LOGIC;
        INC     : in  STD_LOGIC;
        LOAD    : in  STD_LOGIC;
        DATA_IN : in  STD_LOGIC_VECTOR(7 downto 0);
        PC_OUT  : out STD_LOGIC_VECTOR(7 downto 0)
    );
end PC;

architecture RTL of PC is
    signal pc_reg : UNSIGNED(7 downto 0) := (others => '0');
begin
    process(CLK)
    begin
        if rising_edge(CLK) then
            if RESET = '1' then
                pc_reg <= (others => '0');
            elsif ENABLE = '1' then
                if LOAD = '1' then
                    pc_reg <= UNSIGNED(DATA_IN);
                elsif INC = '1' then
                    pc_reg <= pc_reg + 1;
                end if;
            end if;
        end if;
    end process;

    PC_OUT <= STD_LOGIC_VECTOR(pc_reg);
end RTL;