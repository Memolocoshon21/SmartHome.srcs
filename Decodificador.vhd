library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity DecodificadorBCD is
    Port ( bcd : in STD_LOGIC_VECTOR (3 downto 0);
           seg : out STD_LOGIC_VECTOR (6 downto 0));
end DecodificadorBCD;


architecture Behavioral of DecodificadorBCD is
begin

process(bcd)
    begin
        case bcd is
            when "0000" => seg <= "1111110"; -- 0
            when "0001" => seg <= "0110000"; -- 1
            when "0010" => seg <= "1101101"; -- 2
            when "0011" => seg <= "1111001"; -- 3
            when "0100" => seg <= "0110011"; -- 4
            when others => seg <= "0000000"; -- apagado
        end case;
    end process;


end Behavioral;