-- ============================================================
--  COMPONENTE 6: MEMORIA (RAM + ROM de programa)
--  Archivo : 06_Memoria.vhd
--
--  Función  : Contiene dos bloques de memoria:
--
--    ROM (posiciones 0x00–0x0F, 16 instrucciones):
--      Programa hardcoded. Contiene las instrucciones que la
--      CPU ejecuta en cada ciclo para verificar el código.
--      Solo lectura — no puede modificarse en ejecución.
--
--    RAM (posiciones 0x10–0xFF, 240 bytes):
--      Memoria de datos. Guarda el código cifrado del intento
--      actual y resultados intermedios.
--
--  Formato de instrucción (8 bits):
--    [7:4] OPCODE  (4 bits → qué hacer)
--    [3:0] OPERAND (4 bits → con qué hacerlo)
--
--  Programa almacenado en ROM:
--    Pos 0x00 → 0x00 : LOAD_ACC  | Lee DATA_IN al ACC
--    Pos 0x01 → 0x10 : XOR_KEY   | ACC = ACC XOR MASTER_KEY
--    Pos 0x02 → 0x71 : MOV_REG   | R1 = ACC (guarda resultado)
--    Pos 0x03 → 0x20 : STORE_MAR | RAM[MAR] = ACC
--    Pos 0x04 → 0x40 : CMP_OUT   | Compara ACC con password
--    Pos 0x05 → 0x50 : OUT_PORT  | DATA_OUT = ACC
--    Pos 0x06–0x0F   : NOP        | Sin operación
--
--  Entradas :
--    CLK      Reloj del sistema
--    RESET    Reset síncrono
--    ADDR     [7:0] Dirección (viene del MAR)
--    DATA_IN  [7:0] Dato a escribir en RAM
--    WR_EN    Write Enable: '1' solo para escritura en RAM
--
--  Salidas  :
--    DATA_OUT [7:0] Dato leído (ROM o RAM según dirección)
-- ============================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Memoria is
    Port (
        CLK      : in  STD_LOGIC;
        RESET    : in  STD_LOGIC;
        ADDR     : in  STD_LOGIC_VECTOR(7 downto 0);
        DATA_IN  : in  STD_LOGIC_VECTOR(7 downto 0);
        WR_EN    : in  STD_LOGIC;
        DATA_OUT : out STD_LOGIC_VECTOR(7 downto 0)
    );
end Memoria;

architecture RTL of Memoria is

    -- --------------------------------------------------------
    -- ROM: programa de verificación de la chapa
    -- --------------------------------------------------------
    type ROM_TYPE is array (0 to 15) of STD_LOGIC_VECTOR(7 downto 0);
    constant ROM : ROM_TYPE := (
        --  Bin        Hex  Instrucción
        "00000000", -- 0x00  LOAD_ACC  ← Lee código del puerto DATA_IN
        "00010000", -- 0x10  XOR_KEY   ← Encripta con MASTER_KEY 0xB5
        "01110001", -- 0x71  MOV_REG R1← Guarda cifrado en R1
        "00100000", -- 0x20  STORE_MAR ← RAM[MAR] = ACC
        "01000000", -- 0x40  CMP_OUT   ← Compara con 0xE3
        "01010000", -- 0x50  OUT_PORT  ← DATA_OUT = ACC
        "11110000", -- NOP
        "11110000", -- NOP
        "11110000", -- NOP
        "11110000", -- NOP
        "11110000", -- NOP
        "11110000", -- NOP
        "11110000", -- NOP
        "11110000", -- NOP
        "11110000", -- NOP
        "11110000"  -- NOP
    );

    -- --------------------------------------------------------
    -- RAM: 240 bytes de datos (direcciones 0x10–0xFF)
    -- --------------------------------------------------------
    type RAM_TYPE is array (0 to 239) of STD_LOGIC_VECTOR(7 downto 0);
    signal RAM : RAM_TYPE := (others => (others => '0'));

begin

    -- Escritura en RAM (síncrona)
    process(CLK)
        variable ram_idx : INTEGER;
    begin
        if rising_edge(CLK) then
            if RESET = '1' then
                RAM <= (others => (others => '0'));

            elsif WR_EN = '1' then
                -- Solo escribe si la dirección está en zona RAM (>= 0x10)
                if UNSIGNED(ADDR) >= 16 then
                    ram_idx      := TO_INTEGER(UNSIGNED(ADDR)) - 16;
                    RAM(ram_idx) <= DATA_IN;
                end if;
                -- Intentar escribir en ROM no hace nada (zona protegida)
            end if;
        end if;
    end process;

    -- Lectura combinacional: ROM o RAM según dirección
    DATA_OUT <= ROM(TO_INTEGER(UNSIGNED(ADDR)))
                    when UNSIGNED(ADDR) < 16
               else RAM(TO_INTEGER(UNSIGNED(ADDR)) - 16);

end RTL;