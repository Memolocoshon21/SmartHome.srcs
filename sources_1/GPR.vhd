-- ============================================================
--  COMPONENTE 3: BANCO DE REGISTROS GPR (General Purpose Registers)
--  Archivo : 03_GPR.vhd
--
--  Función  : Cuatro registros de 8 bits de acceso ultrarrápido.
--             Evitan ir a la RAM para datos temporales frecuentes.
--
--  Registros:
--    R0 [00] → Operando auxiliar para la ALU (ADD)
--    R1 [01] → Almacena el resultado cifrado del intento actual
--    R2 [10] → Contador de intentos fallidos (0, 1, 2 → bloqueo)
--    R3 [11] → Registro de estado general / uso libre
--
--  Entradas :
--    CLK      Reloj del sistema
--    RESET    Reset síncrono: todos los registros = 0x00
--    ENABLE   Habilita la CPU
--    WR_EN    Write Enable: '1' = escribe en el registro seleccionado
--    WR_SEL   [1:0] Qué registro escribir (00=R0, 01=R1, 10=R2, 11=R3)
--    RD_SEL   [1:0] Qué registro leer  (lectura siempre disponible)
--    DATA_IN  [7:0] Dato a escribir (viene del Acumulador)
--
--  Salidas  :
--    DATA_OUT [7:0] Contenido del registro seleccionado por RD_SEL
--    R2_OUT   [7:0] Salida directa de R2 para la lógica de bloqueo
-- ============================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity GPR is
    Port (
        CLK      : in  std_logic;
        RESET    : in  std_logic;
        ENABLE   : in  std_logic;
        WR_EN    : in  std_logic;
        WR_SEL   : in  std_logic_vector(1 downto 0);
        RD_SEL   : in  std_logic_vector(1 downto 0);
        DATA_IN  : in  std_logic_vector(7 downto 0);
        DATA_OUT : out std_logic_vector(7 downto 0);
        R2_OUT   : out std_logic_vector(7 downto 0)
    );
end GPR;

architecture RTL of GPR is

    -- Los cuatro registros en un arreglo
    type REG_ARRAY is array (0 to 3) of std_logic_vector(7 downto 0);
    signal REGS : REG_ARRAY := (others => (others => '0'));

begin

    -- Puerto de ESCRITURA: síncrono con reloj
    process(CLK)
        variable idx : INTEGER range 0 to 3;
    begin
        if rising_edge(CLK) then
            if RESET = '1' then
                -- Limpia todos los registros incluyendo R2 (contador de intentos)
                REGS <= (others => (others => '0'));

            elsif ENABLE = '1' and WR_EN = '1' then
                idx        := TO_INTEGER(UNSIGNED(WR_SEL));
                REGS(idx)  <= DATA_IN;
            end if;
        end if;
    end process;

    -- Puerto de LECTURA: combinacional, sin latencia
    DATA_OUT <= REGS(TO_INTEGER(UNSIGNED(RD_SEL)));

    -- R2 siempre visible: la UC lo monitorea para detectar bloqueo
    R2_OUT <= REGS(2);

end RTL;