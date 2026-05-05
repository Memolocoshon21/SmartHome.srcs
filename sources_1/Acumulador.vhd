-- ============================================================
--  COMPONENTE 2: ACUMULADOR (ACC)
--  Archivo : 02_Acumulador.vhd
--
--  Función  : Registro central de 8 bits. Almacena el operando
--             activo y el resultado de cada operación de la ALU.
--             Todo dato que procesa la CPU pasa por aquí.
--
--  Entradas :
--    CLK      Reloj del sistema
--    RESET    Reset síncrono activo-alto → ACC = 0x00
--    ENABLE   Habilita la CPU
--    LOAD     Señal de carga: '1' = acepta nuevo dato en DATA_IN
--    DATA_IN  [7:0] Dato a cargar (viene de ALU, RAM o puerto)
--
--  Salidas  :
--    DATA_OUT [7:0] Valor actual del acumulador (siempre visible)
-- ============================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Acumulador is
    Port (
        CLK      : in  std_logic ;
        RESET    : in  std_logic ;
        ENABLE   : in  std_logic ;
        LOAD     : in  std_logic ;
        DATA_IN  : in  STD_LOGIC_VECTOR(7 downto 0);
        DATA_OUT : out STD_LOGIC_VECTOR(7 downto 0)
    );
end Acumulador;


architecture RTL of Acumulador is

    signal acc_reg : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

begin

    process(CLK)
    begin
        if rising_edge(CLK) then
            if RESET = '1' then
                -- Reset síncrono: limpia el acumulador inmediatamente
                acc_reg <= (others => '0');

            elsif ENABLE = '1' and LOAD = '1' then
                -- Carga el nuevo dato solo cuando LOAD y ENABLE están activos
                acc_reg <= DATA_IN;

            end if;
            -- Si LOAD = '0', el ACC retiene su valor (no hace nada)
        end if;
    end process;

    DATA_OUT <= acc_reg;

end RTL;