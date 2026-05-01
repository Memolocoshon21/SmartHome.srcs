library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ALU is
generic (
        n : integer := 3   
    );
    port (
        clave_ingresada  : in  STD_LOGIC_VECTOR(n-1 downto 0);
        clave_almacenada : in  STD_LOGIC_VECTOR(n-1 downto 0);
        clave_ok         : out STD_LOGIC
    );
end ALU;

architecture Behavioral of ALU is
   signal xnor_bits : STD_LOGIC_VECTOR(N-1 downto 0);
begin
     -- XNOR bit a bit (equivalente a NOT NAND + AND):
    -- si todos los bits son iguales → todos en '1' → clave_ok = '1'
    xnor_bits <= clave_ingresada XNOR clave_almacenada;

    -- NAND de reducción: si CUALQUIER bit difiere → clave_ok = '0'
    clave_ok <= xnor_bits(0) AND xnor_bits(1) AND
                xnor_bits(2);

end Behavioral;