-- ============================================================
--  COMPONENTE 7: DECODIFICADOR DE INSTRUCCIONES
--  Archivo : 07_Decodificador.vhd
--
--  Función  : Lógica combinacional pura. Recibe los 8 bits del
--             Instruction Register (IR) y los descompone en:
--               OPCODE   [3:0] → qué operación ejecutar
--               OPERAND  [3:0] → con qué dato o registro operar
--
--             Además, genera la señal ALU_OP de 2 bits que
--             conecta directamente con la ALU.
--
--  Tabla de OPCODES (IR[7:4]):
--    0000 → LOAD_ACC  : ACC ← DATA_IN (puerto entrada)
--    0001 → XOR_KEY   : ACC ← ACC XOR MASTER_KEY  (encripta)
--    0010 → STORE_MAR : RAM[MAR] ← ACC
--    0011 → LOAD_MAR  : ACC ← RAM[MAR]
--    0100 → CMP_OUT   : access_ok ← (ACC == STORED_PASS)
--    0101 → OUT_PORT  : DATA_OUT ← ACC
--    0110 → ADD_REG   : ACC ← ACC + GPR[OPERAND]
--    0111 → MOV_REG   : GPR[OPERAND] ← ACC
--    1000 → INC_R2    : R2 ← R2 + 1  (incrementa intentos)
--    1111 → NOP       : sin operación
--
--  Entradas :
--    IR [7:0]  Instrucción completa del Instruction Register
--
--  Salidas  :
--    OPCODE  [3:0]  Código de operación
--    OPERAND [3:0]  Operando (índice de registro u otro)
--    ALU_OP  [1:0]  Operación para la ALU
--                   "00"=PASS, "01"=XOR, "10"=ADD, "11"=AND
-- ============================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Decodificador is
    Port (
        IR      : in  STD_LOGIC_VECTOR(7 downto 0);
        OPCODE  : out STD_LOGIC_VECTOR(3 downto 0);
        OPERAND : out STD_LOGIC_VECTOR(3 downto 0);
        ALU_OP  : out STD_LOGIC_VECTOR(1 downto 0)
    );
end Decodificador;

architecture RTL of Decodificador is

    -- Constantes de opcode para legibilidad
    constant OP_LOAD_ACC  : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    constant OP_XOR_KEY   : STD_LOGIC_VECTOR(3 downto 0) := "0001";
    constant OP_STORE_MAR : STD_LOGIC_VECTOR(3 downto 0) := "0010";
    constant OP_LOAD_MAR  : STD_LOGIC_VECTOR(3 downto 0) := "0011";
    constant OP_CMP_OUT   : STD_LOGIC_VECTOR(3 downto 0) := "0100";
    constant OP_OUT_PORT  : STD_LOGIC_VECTOR(3 downto 0) := "0101";
    constant OP_ADD_REG   : STD_LOGIC_VECTOR(3 downto 0) := "0110";
    constant OP_MOV_REG   : STD_LOGIC_VECTOR(3 downto 0) := "0111";
    constant OP_INC_R2    : STD_LOGIC_VECTOR(3 downto 0) := "1000";
    constant OP_NOP       : STD_LOGIC_VECTOR(3 downto 0) := "1111";

begin

    -- Extracción directa de campos: solo cableado, cero latencia
    OPCODE  <= IR(7 downto 4);
    OPERAND <= IR(3 downto 0);

    -- Decodificación de ALU_OP: combinacional según OPCODE
    process(IR)
    begin
        case IR(7 downto 4) is
            when OP_XOR_KEY  => ALU_OP <= "01";  -- XOR  (encriptación)
            when OP_ADD_REG  => ALU_OP <= "10";  -- ADD
            when OP_INC_R2   => ALU_OP <= "10";  -- ADD (suma +1 al contador)
            when others      => ALU_OP <= "00";  -- PASS (sin operación ALU)
        end case;
    end process;

end RTL;