-- ============================================================
--  COMPONENTE 5: MAR (Memory Address Register)
--  Archivo : 05_MAR.vhd
--
--  Función  : Registro intermediario que mantiene la dirección
--             de memoria activa durante una operación de lectura
--             o escritura. La RAM nunca recibe la dirección
--             directamente del PC — siempre pasa por el MAR.
--
--  ¿Por qué existe el MAR?
--    En arquitectura Von Neumann clásica, la CPU tiene un bus
--    de direcciones separado. El MAR es el registro que "sostiene"
--    la dirección durante el tiempo que la memoria necesita para
--    responder (puede ser varios ciclos en RAM real).
--
--  Entradas :
--    CLK      Reloj del sistema
--    RESET    Reset síncrono: MAR = 0x00
--    ENABLE   Habilita la CPU
--    LOAD     '1' = acepta nueva dirección en ADDR_IN
--    ADDR_IN  [7:0] Dirección a cargar (viene del PC o de la UC)
--
--  Salidas  :
--    ADDR_OUT [7:0] Dirección activa (conectada al bus de direcciones RAM)
-- ============================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MAR is
    Port (
        CLK      : in  STD_LOGIC;
        RESET    : in  STD_LOGIC;
        ENABLE   : in  STD_LOGIC;
        LOAD     : in  STD_LOGIC;
        ADDR_IN  : in  STD_LOGIC_VECTOR(7 downto 0);
        ADDR_OUT : out STD_LOGIC_VECTOR(7 downto 0)
    );
end MAR;

architecture RTL of MAR is

    signal mar_reg : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

begin

    process(CLK)
    begin
        if rising_edge(CLK) then
            if RESET = '1' then
                mar_reg <= (others => '0');

            elsif ENABLE = '1' and LOAD = '1' then
                -- Captura la dirección que pide la UC
                mar_reg <= ADDR_IN;
            end if;
        end if;
    end process;

    ADDR_OUT <= mar_reg;

end RTL;