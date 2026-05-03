-- ============================================================
--  TESTBENCH COMPLETO: CHAPA_CPU_TB
--  Archivo : 11_Testbench.vhd
--
--  Pruebas incluidas:
--    TEST 1 → Código CORRECTO en el primer intento (0x56)
--             Espera: CHAPA_OPEN='1', LED="10", intentos=3
--
--    TEST 2 → Reset y luego código INCORRECTO (intento 1/3)
--             Espera: CHAPA_OPEN='0', LED="01", intentos restantes=2
--
--    TEST 3 → Código INCORRECTO (intento 2/3)
--             Espera: CHAPA_OPEN='0', LED="01", intentos restantes=1
--
--    TEST 4 → Código INCORRECTO (intento 3/3) → BLOQUEO
--             Espera: LOCKED='1', LED="11", CHAPA_OPEN='0'
--
--    TEST 5 → Intenta código correcto DESPUÉS de bloqueo
--             Espera: sistema ignora el intento, sigue LOCKED='1'
--
--    TEST 6 → RESET durante bloqueo → sistema se recupera
--             Espera: LOCKED='0', sistema vuelve a funcionar
--
--    TEST 7 → Código correcto tras reset
--             Espera: CHAPA_OPEN='1'
--
--  Código correcto: 0x56 (86 decimal = "01010110")
--  MASTER_KEY:      0xB5 ("10110101")
--  STORED_PASS:     0xE3 ("11100011") = 0x56 XOR 0xB5
-- ============================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CHAPA_CPU_TB is
end CHAPA_CPU_TB;

architecture SIM of CHAPA_CPU_TB is

    -- Señales del DUT (Device Under Test)
    signal CLK           : STD_LOGIC := '0';
    signal RESET         : STD_LOGIC := '1';
    signal ENABLE        : STD_LOGIC := '0';
    signal DATA_IN       : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal DATA_READY    : STD_LOGIC := '0';
    signal DATA_OUT      : STD_LOGIC_VECTOR(7 downto 0);
    signal ATTEMPTS_LEFT : STD_LOGIC_VECTOR(1 downto 0);
    signal LOCKED        : STD_LOGIC;
    signal CHAPA_OPEN    : STD_LOGIC;
    signal CHAPA_LED     : STD_LOGIC_VECTOR(1 downto 0);

    -- Constantes de prueba
    constant CORRECT_CODE : STD_LOGIC_VECTOR(7 downto 0) := "01010110"; -- 0x56
    constant WRONG_CODE_1 : STD_LOGIC_VECTOR(7 downto 0) := "11001100"; -- 0xCC
    constant WRONG_CODE_2 : STD_LOGIC_VECTOR(7 downto 0) := "00110011"; -- 0x33
    constant WRONG_CODE_3 : STD_LOGIC_VECTOR(7 downto 0) := "10101010"; -- 0xAA

    -- Periodo de reloj: 10ns = 100MHz
    constant CLK_PERIOD : time := 10 ns;

    -- Procedimiento para enviar un código y esperar resultado
    procedure send_code (
        signal d_in   : out STD_LOGIC_VECTOR(7 downto 0);
        signal d_rdy  : out STD_LOGIC;
        constant code : in  STD_LOGIC_VECTOR(7 downto 0);
        constant wait_cycles : in INTEGER
    ) is
    begin
        d_in  <= code;
        d_rdy <= '1';
        wait for CLK_PERIOD * 2;
        d_rdy <= '0';
        wait for CLK_PERIOD * wait_cycles;
    end procedure;

begin

    -- Instancia del DUT
    DUT: entity work.CHAPA_CPU
        port map (
            CLK           => CLK,
            RESET         => RESET,
            ENABLE        => ENABLE,
            DATA_IN       => DATA_IN,
            DATA_READY    => DATA_READY,
            DATA_OUT      => DATA_OUT,
            ATTEMPTS_LEFT => ATTEMPTS_LEFT,
            LOCKED        => LOCKED,
            CHAPA_OPEN    => CHAPA_OPEN,
            CHAPA_LED     => CHAPA_LED
        );

    -- Generador de reloj
    CLK <= not CLK after CLK_PERIOD / 2;

    -- ============================================================
    -- SECUENCIA DE PRUEBAS
    -- ============================================================
    STIM: process
    begin
        -- --------------------------------------------------------
        -- INICIALIZACIÓN
        -- --------------------------------------------------------
        report "======================================";
        report " TESTBENCH: CHAPA_CPU 3 intentos";
        report "======================================";

        RESET  <= '1';
        ENABLE <= '0';
        wait for CLK_PERIOD * 5;

        RESET  <= '0';
        ENABLE <= '1';
        wait for CLK_PERIOD * 3;

        -- --------------------------------------------------------
        -- TEST 1: Código correcto en primer intento
        -- --------------------------------------------------------
        report "[TEST 1] Enviando codigo CORRECTO (0x56)...";
        send_code(DATA_IN, DATA_READY, CORRECT_CODE, 20);

        assert CHAPA_OPEN = '1'
            report "[FAIL] TEST 1: Chapa no abrio con codigo correcto" severity ERROR;
        assert CHAPA_LED = "10"
            report "[FAIL] TEST 1: LED no muestra verde" severity ERROR;
        assert LOCKED = '0'
            report "[FAIL] TEST 1: Sistema bloqueado incorrectamente" severity ERROR;

        report "[PASS] TEST 1: Acceso correcto - chapa abierta";

        -- --------------------------------------------------------
        -- RESET para empezar la secuencia de intentos fallidos
        -- --------------------------------------------------------
        RESET <= '1';
        wait for CLK_PERIOD * 3;
        RESET <= '0';
        wait for CLK_PERIOD * 3;

        -- --------------------------------------------------------
        -- TEST 2: Primer intento fallido (1/3)
        -- --------------------------------------------------------
        report "[TEST 2] Intento fallido 1/3 (0xCC)...";
        send_code(DATA_IN, DATA_READY, WRONG_CODE_1, 20);

        assert CHAPA_OPEN = '0'
            report "[FAIL] TEST 2: Chapa abrio con codigo incorrecto" severity ERROR;
        assert CHAPA_LED = "01"
            report "[FAIL] TEST 2: LED no muestra rojo" severity ERROR;
        assert LOCKED = '0'
            report "[FAIL] TEST 2: Bloqueo prematuro en intento 1" severity ERROR;
        assert ATTEMPTS_LEFT = "10"
            report "[FAIL] TEST 2: Contador de intentos incorrecto (esperado 2)" severity ERROR;

        report "[PASS] TEST 2: Acceso denegado - quedan 2 intentos";

        -- --------------------------------------------------------
        -- TEST 3: Segundo intento fallido (2/3)
        -- --------------------------------------------------------
        report "[TEST 3] Intento fallido 2/3 (0x33)...";
        send_code(DATA_IN, DATA_READY, WRONG_CODE_2, 20);

        assert CHAPA_OPEN = '0'
            report "[FAIL] TEST 3: Chapa abrio con codigo incorrecto" severity ERROR;
        assert LOCKED = '0'
            report "[FAIL] TEST 3: Bloqueo prematuro en intento 2" severity ERROR;
        assert ATTEMPTS_LEFT = "01"
            report "[FAIL] TEST 3: Contador de intentos incorrecto (esperado 1)" severity ERROR;

        report "[PASS] TEST 3: Acceso denegado - queda 1 intento";

        -- --------------------------------------------------------
        -- TEST 4: Tercer intento fallido → BLOQUEO (3/3)
        -- --------------------------------------------------------
        report "[TEST 4] Intento fallido 3/3 (0xAA) - debe BLOQUEAR...";
        send_code(DATA_IN, DATA_READY, WRONG_CODE_3, 20);

        assert LOCKED = '1'
            report "[FAIL] TEST 4: Sistema NO se bloqueo despues de 3 intentos" severity ERROR;
        assert CHAPA_OPEN = '0'
            report "[FAIL] TEST 4: Chapa abierta con sistema bloqueado" severity ERROR;
        assert CHAPA_LED = "11"
            report "[FAIL] TEST 4: LED no indica bloqueo (esperado 11)" severity ERROR;
        assert ATTEMPTS_LEFT = "00"
            report "[FAIL] TEST 4: Contador no muestra 0 intentos" severity ERROR;

        report "[PASS] TEST 4: Sistema BLOQUEADO correctamente";

        -- --------------------------------------------------------
        -- TEST 5: Intento de entrada con código correcto BLOQUEADO
        -- El sistema debe ignorar el código aunque sea correcto
        -- --------------------------------------------------------
        report "[TEST 5] Codigo correcto con sistema bloqueado - debe ignorarse...";
        send_code(DATA_IN, DATA_READY, CORRECT_CODE, 20);

        assert CHAPA_OPEN = '0'
            report "[FAIL] TEST 5: Chapa abrio con sistema bloqueado" severity ERROR;
        assert LOCKED = '1'
            report "[FAIL] TEST 5: Sistema perdio estado de bloqueo" severity ERROR;

        report "[PASS] TEST 5: Sistema bloqueado ignora codigo correcto";

        -- --------------------------------------------------------
        -- TEST 6: RESET durante bloqueo → recuperación
        -- --------------------------------------------------------
        report "[TEST 6] Aplicando RESET para recuperar sistema bloqueado...";
        RESET <= '1';
        wait for CLK_PERIOD * 5;
        RESET <= '0';
        wait for CLK_PERIOD * 5;

        assert LOCKED = '0'
            report "[FAIL] TEST 6: Sistema sigue bloqueado despues de RESET" severity ERROR;
        assert CHAPA_OPEN = '0'
            report "[FAIL] TEST 6: Chapa abierta despues de RESET" severity ERROR;
        assert CHAPA_LED = "01"
            report "[FAIL] TEST 6: LED no muestra estado inicial (rojo)" severity ERROR;

        report "[PASS] TEST 6: Sistema recuperado con RESET";

        -- --------------------------------------------------------
        -- TEST 7: Código correcto después del reset
        -- --------------------------------------------------------
        report "[TEST 7] Codigo correcto post-RESET (0x56)...";
        send_code(DATA_IN, DATA_READY, CORRECT_CODE, 20);

        assert CHAPA_OPEN = '1'
            report "[FAIL] TEST 7: Chapa no abrio post-RESET" severity ERROR;
        assert LOCKED = '0'
            report "[FAIL] TEST 7: Sistema bloqueado post-RESET" severity ERROR;
        assert CHAPA_LED = "10"
            report "[FAIL] TEST 7: LED no muestra verde post-RESET" severity ERROR;

        report "[PASS] TEST 7: Sistema funcionando correctamente post-RESET";

        -- --------------------------------------------------------
        -- FIN
        -- --------------------------------------------------------
        report "======================================";
        report " TODOS LOS TESTS COMPLETADOS";
        report "======================================";

        wait; -- Fin de simulación
    end process;

end SIM;