-- ============================================================
--  COMPONENTE 9: PUERTOS DE ENTRADA / SALIDA
--  Archivo : 09_Puertos.vhd
--
--  Función  : Interfaz eléctrica entre el FPGA y el ESP32.
--             Gestiona la transferencia de datos de 8 bits en
--             ambas direcciones con handshake simple.
--
--  Puerto de ENTRADA (del ESP32 al FPGA):
--    DATA_IN    [7:0]  Código de acceso presentado por el ESP32
--    DATA_READY        '1' cuando DATA_IN tiene un valor nuevo y válido
--                      (el ESP32 lo levanta al presentar el código y
--                       lo baja cuando termina)
--
--  Puerto de SALIDA (del FPGA al ESP32):
--    DATA_OUT   [7:0]  Resultado cifrado y estado del sistema
--    OUT_EN            La UC activa esto para que el dato salga
--    CHAPA_OPEN        '1' = relé activo = chapa abierta
--    CHAPA_LED  [1:0]  Estado visual de la chapa
--    LOCKED            '1' = sistema bloqueado (3 intentos agotados)
--    ATTEMPTS   [1:0]  Intentos fallidos restantes (3, 2, 1, 0)
--
--  Nota sobre ATTEMPTS:
--    Se calcula como (3 - R2_DATA[1:0]) para mostrar al ESP32
--    cuántos intentos le quedan. El ESP32 puede mandar esto
--    de vuelta a la app para mostrar un mensaje al usuario.
--
--  Entradas internas (vienen de UC y ACC):
--    ACC_DATA   [7:0]  Valor del Acumulador
--    R2_DATA    [7:0]  Contador de intentos fallidos (GPR R2)
--    ACCESS_OK         Señal de acceso correcto de la UC
--    LOCKED_IN         Señal de bloqueo de la UC
--    CHAPA_OPEN_IN     Señal de apertura de la UC
--    CHAPA_LED_IN[1:0] Estado LED de la UC
--    OUT_EN_IN         Habilita captura de dato de salida
-- ============================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Puertos is
    Port (
        CLK           : in  STD_LOGIC;
        RESET         : in  STD_LOGIC;
        ENABLE        : in  STD_LOGIC;

        -- Puerto físico de entrada (pines del FPGA hacia ESP32)
        DATA_IN       : in  STD_LOGIC_VECTOR(7 downto 0);
        DATA_READY    : in  STD_LOGIC;

        -- Señales internas (de la CPU)
        ACC_DATA      : in  STD_LOGIC_VECTOR(7 downto 0);
        R2_DATA       : in  STD_LOGIC_VECTOR(7 downto 0);
        ACCESS_OK     : in  STD_LOGIC;
        LOCKED_IN     : in  STD_LOGIC;
        CHAPA_OPEN_IN : in  STD_LOGIC;
        CHAPA_LED_IN  : in  STD_LOGIC_VECTOR(1 downto 0);
        OUT_EN_IN     : in  STD_LOGIC;

        -- Puerto físico de salida (pines del FPGA hacia ESP32 y relé)
        DATA_OUT      : out STD_LOGIC_VECTOR(7 downto 0);
        DATA_IN_BUF   : out STD_LOGIC_VECTOR(7 downto 0); -- DATA_IN bufferizado
        CHAPA_OPEN    : out STD_LOGIC;
        CHAPA_LED     : out STD_LOGIC_VECTOR(1 downto 0);
        LOCKED        : out STD_LOGIC;
        ATTEMPTS_LEFT : out STD_LOGIC_VECTOR(1 downto 0)  -- intentos restantes
    );
end Puertos;

architecture RTL of Puertos is

    signal data_out_reg  : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal data_in_latch : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal attempts_reg  : UNSIGNED(1 downto 0)         := "11"; -- empieza en 3

begin

    -- Latch de entrada: captura DATA_IN cuando DATA_READY sube
    -- y calcula intentos restantes
    process(CLK)
    begin
        if rising_edge(CLK) then
            if RESET = '1' then
                data_in_latch <= (others => '0');
                data_out_reg  <= (others => '0');
                attempts_reg  <= "11";  -- 3 intentos disponibles

            elsif ENABLE = '1' then

                -- Captura el código cuando el ESP32 lo presenta
                if DATA_READY = '1' then
                    data_in_latch <= DATA_IN;
                end if;

                -- Actualiza DATA_OUT cuando la UC lo indica
                if OUT_EN_IN = '1' then
                    data_out_reg <= ACC_DATA;
                end if;

                -- Calcula intentos restantes: 3 - R2_DATA
                -- R2_DATA solo puede ser 0, 1, 2 o 3
                if UNSIGNED(R2_DATA) <= 3 then
                    attempts_reg <= TO_UNSIGNED(3, 2) -
                                    UNSIGNED(R2_DATA(1 downto 0));
                else
                    attempts_reg <= "00";
                end if;

            end if;
        end if;
    end process;

    -- Asignaciones de salida
    DATA_OUT      <= data_out_reg;
    DATA_IN_BUF   <= data_in_latch;
    CHAPA_OPEN    <= CHAPA_OPEN_IN;
    CHAPA_LED     <= CHAPA_LED_IN;
    LOCKED        <= LOCKED_IN;
    ATTEMPTS_LEFT <= STD_LOGIC_VECTOR(attempts_reg);

end RTL;