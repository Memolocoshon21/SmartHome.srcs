library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity contador_intentos is
    Port (
        clk     : in  STD_LOGIC;
        reset   : in  STD_LOGIC;
        error   : in  STD_LOGIC; -- señal de intento fallido (puede venir mal)
        count   : out STD_LOGIC_VECTOR (2 downto 0);
        lock    : out STD_LOGIC
    );
end contador_intentos;

architecture Behavioral of contador_intentos is

    signal contador      : unsigned(2 downto 0) := "000";
    signal error_prev    : STD_LOGIC := '0'; -- para detectar flanco
    signal error_pulse   : STD_LOGIC := '0';

begin

    -- 🔹 Detector de flanco (0 → 1)
    process(clk)
    begin
        if rising_edge(clk) then
            error_pulse <= error and not error_prev;
            error_prev  <= error;
        end if;
    end process;


    -- 🔹 Contador de intentos
    process(clk, reset)
    begin
        if reset = '1' then
            contador <= "000";

        elsif rising_edge(clk) then
            -- Solo cuenta si hay pulso de error y no está bloqueado
            if error_pulse = '1' then
                if contador < "100" then
                    contador <= contador + 1;
                end if;
            end if;
        end if;
    end process;


    -- 🔹 Salidas
    count <= std_logic_vector(contador);

    -- Bloqueo cuando llega a 4
    lock <= '1' when contador = "100" else '0';

end Behavioral;