-- ============================================================
--  COMPONENTE 1: ALU (Unidad Aritmético-Lógica)
--  Archivo : 01_ALU.vhd
--
--  Función  : Realiza operaciones aritméticas y lógicas de 8 bits.
--             La operación XOR es la que encripta el código de acceso.
--
--  Entradas :
--    A      [7:0]  Operando A  (viene del Acumulador)
--    B      [7:0]  Operando B  (viene de GPR o de la clave maestra)
--    OP     [1:0]  Selección de operación
--
--  Salidas  :
--    RESULT [7:0]  Resultado de la operación
--    FLAG_Z        Flag Zero  → resultado = 0x00
--    FLAG_C        Flag Carry → hubo acarreo en suma
--
--  Tabla de operaciones (OP):
--    "00" → PASS  : RESULT = A         (sin modificar)
--    "01" → XOR   : RESULT = A XOR B   (ENCRIPTACIÓN con clave)
--    "10" → ADD   : RESULT = A + B     (suma con carry)
--    "11" → AND   : RESULT = A AND B   (máscara de bits)
-- ============================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ALU is
    Port (
        A      : in  STD_LOGIC_VECTOR(7 downto 0);
        B      : in  STD_LOGIC_VECTOR(7 downto 0);
        OP     : in  STD_LOGIC_VECTOR(1 downto 0);
        RESULT : out STD_LOGIC_VECTOR(7 downto 0);
        FLAG_Z : out STD_LOGIC;
        FLAG_C : out STD_LOGIC
    );
end ALU;

architecture RTL of ALU is

    signal result_int : STD_LOGIC_VECTOR(7 downto 0);
    signal carry_int  : STD_LOGIC;

begin

    -- Proceso combinacional puro: sin reloj, responde inmediatamente
    process(A, B, OP)
        variable sum : UNSIGNED(8 downto 0); -- 9 bits para capturar carry
    begin
        carry_int <= '0';

        case OP is

            when "00" =>   -- PASS: A pasa sin modificar
                result_int <= A;

            when "01" =>   -- XOR: encriptación bit a bit con clave maestra
                result_int <= A XOR B;

            when "10" =>   -- ADD: A + B, el bit 8 del resultado es carry
                sum        := UNSIGNED('0' & A) + UNSIGNED('0' & B);
                result_int <= STD_LOGIC_VECTOR(sum(7 downto 0));
                carry_int  <= sum(8);

            when "11" =>   -- AND: máscara para aislar bits específicos
                result_int <= A AND B;

            when others =>
                result_int <= (others => '0');

        end case;
    end process;

    RESULT <= result_int;
    FLAG_C <= carry_int;
    FLAG_Z <= '1' when result_int = "00000000" else '0';

end RTL;