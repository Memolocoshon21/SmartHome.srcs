-- ============================================================
--  COMPONENTE 8: UNIDAD DE CONTROL (UC / FSM)
--  Archivo : 08_UnidadControl.vhd
--
--  Función  : Director de orquesta de la CPU. Implementa la
--             máquina de estados (FSM) de 4 etapas y genera
--             todas las señales de control para los demás
--             componentes. También maneja la lógica de bloqueo
--             tras 3 intentos fallidos consecutivos.
--
--  Estados de la FSM:
--    S_IDLE      → Espera señal de nuevo intento (DATA_READY)
--    S_FETCH     → Trae instrucción de ROM al IR
--    S_DECODE    → Decodifica IR, prepara señales de control
--    S_EXECUTE   → Ejecuta la operación correspondiente
--    S_WRITEBACK → Actualiza salidas físicas (chapa, LED)
--    S_LOCKED    → Sistema bloqueado, ignora todo input
--
--  Lógica de bloqueo (3 intentos):
--    R2 (GPR registro 2) actúa como contador de intentos fallidos.
--    Cada vez que CMP_OUT falla → R2 se incrementa.
--    Cuando R2 = 3 (0x03) → UC entra en S_LOCKED.
--    Solo RESET puede salir de S_LOCKED.
--
--  Entradas :
--    CLK        Reloj del sistema
--    RESET      Reset síncrono activo-alto
--    ENABLE     Habilita la CPU
--    DATA_READY '1' cuando DATA_IN tiene un nuevo código válido
--    OPCODE     [3:0] Instrucción actual del Decodificador
--    OPERAND    [3:0] Operando de la instrucción actual
--    ACC_DATA   [7:0] Valor actual del Acumulador
--    R2_DATA    [7:0] Contador de intentos (GPR registro 2)
--    PC_OUT     [7:0] Posición actual del PC
--    FLAG_Z     Flag Zero de la ALU
--    FLAG_C     Flag Carry de la ALU
--
--  Salidas de control:
--    PC_INC     Incrementa el PC
--    PC_LOAD    Carga valor directo en PC
--    PC_DIN     [7:0] Valor a cargar en PC
--    MAR_LOAD   Carga dirección en MAR
--    MAR_DIN    [7:0] Dirección a cargar en MAR
--    IR_LOAD    Carga instrucción en IR
--    ACC_LOAD   Carga dato en Acumulador
--    ACC_SRC    [1:0] Fuente del dato para ACC
--               "00"=DATA_IN, "01"=ALU, "10"=RAM, "11"=GPR
--    MEM_WR     Escribe en RAM
--    GPR_WR     Escribe en GPR
--    GPR_WSEL   [1:0] Registro GPR a escribir
--    GPR_RSEL   [1:0] Registro GPR a leer
--    OUT_EN     Habilita salida a DATA_OUT
--    ACCESS_OK  '1' si el código es correcto
--    LOCKED     '1' si el sistema está bloqueado (3 intentos)
--    CHAPA_OPEN Señal directa al relé de la chapa
--    CHAPA_LED  [1:0] "10"=verde/abierta "01"=rojo/cerrada "11"=amarillo/bloqueada
-- ============================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UnidadControl is
    Port (
        -- Globales
        CLK        : in  STD_LOGIC;
        RESET      : in  STD_LOGIC;
        ENABLE     : in  STD_LOGIC;
        DATA_READY : in  STD_LOGIC;

        -- Del Decodificador
        OPCODE     : in  STD_LOGIC_VECTOR(3 downto 0);
        OPERAND    : in  STD_LOGIC_VECTOR(3 downto 0);

        -- Del Acumulador y GPR
        ACC_DATA   : in  STD_LOGIC_VECTOR(7 downto 0);
        R2_DATA    : in  STD_LOGIC_VECTOR(7 downto 0);

        -- Del PC
        PC_OUT     : in  STD_LOGIC_VECTOR(7 downto 0);

        -- Flags de la ALU
        FLAG_Z     : in  STD_LOGIC;
        FLAG_C     : in  STD_LOGIC;

        -- Señales de control hacia demás componentes
        PC_INC     : out STD_LOGIC;
        PC_LOAD    : out STD_LOGIC;
        PC_DIN     : out STD_LOGIC_VECTOR(7 downto 0);
        MAR_LOAD   : out STD_LOGIC;
        MAR_DIN    : out STD_LOGIC_VECTOR(7 downto 0);
        IR_LOAD    : out STD_LOGIC;
        ACC_LOAD   : out STD_LOGIC;
        ACC_SRC    : out STD_LOGIC_VECTOR(1 downto 0);
        MEM_WR     : out STD_LOGIC;
        GPR_WR     : out STD_LOGIC;
        GPR_WSEL   : out STD_LOGIC_VECTOR(1 downto 0);
        GPR_RSEL   : out STD_LOGIC_VECTOR(1 downto 0);
        OUT_EN     : out STD_LOGIC;
        ACCESS_OK  : out STD_LOGIC;
        LOCKED     : out STD_LOGIC;
        CHAPA_OPEN : out STD_LOGIC;
        CHAPA_LED  : out STD_LOGIC_VECTOR(1 downto 0)
    );
end UnidadControl;

architecture RTL of UnidadControl is

    -- Estados de la FSM
    type FSM_STATE is (
        S_IDLE,       -- Esperando nuevo código
        S_FETCH,      -- Trae instrucción de ROM
        S_DECODE,     -- Decodifica la instrucción
        S_EXECUTE,    -- Ejecuta la operación
        S_WRITEBACK,  -- Actualiza salidas físicas
        S_LOCKED      -- Bloqueado por 3 intentos fallidos
    );
    signal state      : FSM_STATE := S_IDLE;
    signal next_state : FSM_STATE;

    -- Password cifrado de referencia: 0x56 XOR 0xB5 = 0xE3
    constant STORED_PASS : STD_LOGIC_VECTOR(7 downto 0) := "11100011"; -- 0xE3

    -- Registro interno de acceso correcto
    signal access_ok_reg  : STD_LOGIC := '0';
    signal locked_reg     : STD_LOGIC := '0';

    -- Constantes de OPCODE
    constant OP_LOAD_ACC  : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    constant OP_XOR_KEY   : STD_LOGIC_VECTOR(3 downto 0) := "0001";
    constant OP_STORE_MAR : STD_LOGIC_VECTOR(3 downto 0) := "0010";
    constant OP_LOAD_MAR  : STD_LOGIC_VECTOR(3 downto 0) := "0011";
    constant OP_CMP_OUT   : STD_LOGIC_VECTOR(3 downto 0) := "0100";
    constant OP_OUT_PORT  : STD_LOGIC_VECTOR(3 downto 0) := "0101";
    constant OP_ADD_REG   : STD_LOGIC_VECTOR(3 downto 0) := "0110";
    constant OP_MOV_REG   : STD_LOGIC_VECTOR(3 downto 0) := "0111";
    constant OP_INC_R2    : STD_LOGIC_VECTOR(3 downto 0) := "1000";

    -- Constante: límite de intentos
    constant MAX_ATTEMPTS : STD_LOGIC_VECTOR(7 downto 0) := "00000011"; -- 3

begin

    -- ==========================================================
    -- FSM: Transición de estados (síncrona)
    -- ==========================================================
    FSM_REG: process(CLK)
    begin
        if rising_edge(CLK) then
            if RESET = '1' then
                state         <= S_IDLE;
                access_ok_reg <= '0';
                locked_reg    <= '0';
            elsif ENABLE = '1' then
                state <= next_state;
            end if;
        end if;
    end process;

    -- ==========================================================
    -- FSM: Lógica de próximo estado y señales de control
    -- ==========================================================
    FSM_LOGIC: process(state, DATA_READY, OPCODE, OPERAND,
                       ACC_DATA, R2_DATA, PC_OUT, FLAG_Z, FLAG_C,
                       access_ok_reg, locked_reg)
    begin
        -- Valores por defecto (todos inactivos)
        next_state <= state;
        PC_INC     <= '0';
        PC_LOAD    <= '0';
        PC_DIN     <= (others => '0');
        MAR_LOAD   <= '0';
        MAR_DIN    <= (others => '0');
        IR_LOAD    <= '0';
        ACC_LOAD   <= '0';
        ACC_SRC    <= "00";
        MEM_WR     <= '0';
        GPR_WR     <= '0';
        GPR_WSEL   <= "00";
        GPR_RSEL   <= "00";
        OUT_EN     <= '0';

        case state is

            -- ------------------------------------------------------
            -- S_IDLE: Espera a que el ESP32 presente un código
            -- ------------------------------------------------------
            when S_IDLE =>
                if locked_reg = '1' then
                    next_state <= S_LOCKED;

                elsif DATA_READY = '1' then
                    -- Nuevo intento: reinicia PC al inicio del programa
                    PC_LOAD    <= '1';
                    PC_DIN     <= (others => '0');
                    next_state <= S_FETCH;
                end if;

            -- ------------------------------------------------------
            -- S_FETCH: Carga instrucción de ROM al IR vía MAR
            -- ------------------------------------------------------
            when S_FETCH =>
                MAR_LOAD   <= '1';
                MAR_DIN    <= PC_OUT;   -- MAR = PC (dirección de instrucción)
                IR_LOAD    <= '1';      -- IR cargará lo que salga de la memoria
                PC_INC     <= '1';      -- PC++ para la siguiente instrucción
                next_state <= S_DECODE;

            -- ------------------------------------------------------
            -- S_DECODE: La UC procesa el OPCODE del Decodificador
            -- ------------------------------------------------------
            when S_DECODE =>
                -- Prepara GPR_RSEL según operando para instrucciones que leen GPR
                GPR_RSEL   <= OPERAND(1 downto 0);
                next_state <= S_EXECUTE;

            -- ------------------------------------------------------
            -- S_EXECUTE: Ejecuta la instrucción actual
            -- ------------------------------------------------------
            when S_EXECUTE =>

                case OPCODE is

                    when OP_LOAD_ACC =>
                        -- ACC ← DATA_IN (código del ESP32)
                        ACC_LOAD   <= '1';
                        ACC_SRC    <= "00";  -- fuente: puerto DATA_IN
                        next_state <= S_FETCH;

                    when OP_XOR_KEY =>
                        -- ACC ← ACC XOR MASTER_KEY (ALU hace XOR con B=MASTER_KEY)
                        ACC_LOAD   <= '1';
                        ACC_SRC    <= "01";  -- fuente: resultado ALU
                        next_state <= S_FETCH;

                    when OP_MOV_REG =>
                        -- GPR[OPERAND] ← ACC
                        GPR_WR     <= '1';
                        GPR_WSEL   <= OPERAND(1 downto 0);
                        next_state <= S_FETCH;

                    when OP_STORE_MAR =>
                        -- RAM[MAR] ← ACC
                        MEM_WR     <= '1';
                        next_state <= S_FETCH;

                    when OP_LOAD_MAR =>
                        -- ACC ← RAM[MAR]
                        ACC_LOAD   <= '1';
                        ACC_SRC    <= "10";  -- fuente: RAM
                        next_state <= S_FETCH;

                    when OP_CMP_OUT =>
                        -- Compara ACC con STORED_PASS
                        -- La decisión real se toma en S_WRITEBACK
                        -- Solo avanzamos aquí
                        next_state <= S_WRITEBACK;

                    when OP_OUT_PORT =>
                        -- DATA_OUT ← ACC
                        OUT_EN     <= '1';
                        next_state <= S_FETCH;

                    when OP_ADD_REG =>
                        -- ACC ← ACC + GPR[OPERAND]
                        GPR_RSEL   <= OPERAND(1 downto 0);
                        ACC_LOAD   <= '1';
                        ACC_SRC    <= "01";  -- fuente: resultado ALU
                        next_state <= S_FETCH;

                    when OP_INC_R2 =>
                        -- R2 ← R2 + 1 (incrementa contador de intentos)
                        GPR_RSEL   <= "10";   -- lee R2
                        GPR_WR     <= '1';
                        GPR_WSEL   <= "10";   -- escribe R2
                        next_state <= S_FETCH;

                    when others =>  -- NOP
                        -- Si PC llegó al final (instrucción NOP tras CMP),
                        -- vuelve a IDLE para esperar el próximo intento
                        next_state <= S_IDLE;

                end case;

            -- ------------------------------------------------------
            -- S_WRITEBACK: Actualiza acceso y maneja intentos
            -- ------------------------------------------------------
            when S_WRITEBACK =>
                if ACC_DATA = STORED_PASS then
                    -- ¡Código correcto! Abre chapa y resetea contador
                    access_ok_reg <= '1';
                    -- Resetea R2 a cero (intentos limpios)
                    GPR_WR   <= '1';
                    GPR_WSEL <= "10";   -- escribe R2 = 0
                    -- El dato a escribir vendrá del mux de ACC_SRC = 0x00
                    -- (la UC fuerza un valor 0 al GPR)
                    OUT_EN   <= '1';
                else
                    -- Código incorrecto: incrementa R2
                    access_ok_reg <= '0';

                    if R2_DATA = MAX_ATTEMPTS then
                        -- Ya fueron 3 intentos → bloquear
                        locked_reg <= '1';
                        next_state <= S_LOCKED;
                    else
                        -- Aún quedan intentos
                        -- GPR R2 se incrementa via INC_R2 en el programa
                        next_state <= S_IDLE;
                    end if;
                end if;

                -- Si no bloqueó, vuelve a IDLE
                if locked_reg = '0' and R2_DATA /= MAX_ATTEMPTS then
                    next_state <= S_IDLE;
                end if;

            -- ------------------------------------------------------
            -- S_LOCKED: Bloqueado. Solo RESET puede salir.
            -- ------------------------------------------------------
            when S_LOCKED =>
                -- Ignora DATA_READY, no ejecuta nada
                -- Solo el RESET del proceso FSM_REG puede cambiar el estado
                next_state <= S_LOCKED;

        end case;
    end process;

    -- ==========================================================
    -- Salidas físicas (combinacional desde registros internos)
    -- ==========================================================
    CHAPA_OPEN <= access_ok_reg and (not locked_reg);

    -- LED:
    --   "10" → Verde  (acceso correcto, chapa abierta)
    --   "01" → Rojo   (acceso denegado / esperando)
    --   "11" → Amarillo/Rojo ambos (BLOQUEADO — 3 intentos)
    CHAPA_LED <= "11" when locked_reg    = '1' else
                 "10" when access_ok_reg = '1' else
                 "01";

    ACCESS_OK <= access_ok_reg;
    LOCKED    <= locked_reg;

end RTL;