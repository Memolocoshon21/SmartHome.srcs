library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity busqueda_clave is
    Port (
        clave_ingresada : in  STD_LOGIC_VECTOR(2 downto 0);
        enter           : in  STD_LOGIC;
        correcta        : out STD_LOGIC;
        incorrecta      : out STD_LOGIC
    );
end busqueda_clave;

architecture Behavioral of busqueda_clave is
begin

process(clave_ingresada, enter)
begin

    correcta   <= '0';
    incorrecta <= '0';

    if enter = '1' then

        if clave_ingresada = "1011" then
            correcta <= '1';
        else
            incorrecta <= '1';
        end if;

    end if;

end process;

end Behavioral;