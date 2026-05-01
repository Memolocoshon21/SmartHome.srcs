----------------------------------------------------------------------------------
-- Universidad: Centro Universitario de Ciencias Exactas. 
-- Estudiante: Sergio Guillermo Trujillo Hernández
-- 
-- Fecha de Creación: 05/01/2026 09:49:18 AM
-- Nombre del Módulo: tb_sistema_clave - Behavioral
-- Nombre del Proyecto: Cerradura Domótica Encriptada
-- Dispositivos en mira: Chapas Eléctricas compatibles con el sistema.
-- Descripción: Cerradura eléctrica conectada a un ESP32 que dicta si la clave para activarla es correcta, mediante un módulo WIFI a través de una app.
-- Versión: Beta 1.0
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_sistema_clave is
--  Port ( );
end tb_sistema_clave;

architecture Behavioral of tb_sistema_clave is

-- ===== Señales para ALU =====
    signal tb_clave_ingresada  : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    signal tb_clave_almacenada : STD_LOGIC_VECTOR(3 downto 0) := "1010";
    signal tb_clave_ok         : STD_LOGIC;

    -- ===== Señales para DecodificadorBCD =====
    signal tb_bcd : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    signal tb_seg : STD_LOGIC_VECTOR(6 downto 0);

    -- ===== Señales para FSM =====
    signal tb_clk        : STD_LOGIC := '0';
    signal tb_reset      : STD_LOGIC := '0';
    signal tb_ingresar   : STD_LOGIC := '0';
    signal tb_bloqueado  : STD_LOGIC := '0';
    signal tb_led_rojo   : STD_LOGIC;
    signal tb_led_azul   : STD_LOGIC;
    signal tb_inc_intento: STD_LOGIC;

    -- ===== Señales para busqueda_clave =====
    signal tb_enter      : STD_LOGIC := '0';
    signal tb_correcta   : STD_LOGIC;
    signal tb_incorrecta : STD_LOGIC;

    -- ===== Señales para contador_intentos =====
    signal tb_error : STD_LOGIC := '0';
    signal tb_count : STD_LOGIC_VECTOR(2 downto 0);
    signal tb_lock  : STD_LOGIC;

    -- Periodo de reloj
    constant CLK_PERIOD : time := 10 ns;


begin

 U_ALU : entity work.ALU
        generic map(n => 4)
        port map(
            clave_ingresada  => tb_clave_ingresada,
            clave_almacenada => tb_clave_almacenada,
            clave_ok         => tb_clave_ok
        );

    U_BCD : entity work.DecodificadorBCD
        port map(
            bcd => tb_bcd,
            seg => tb_seg
        );

    U_FSM : entity work.FSM_Control
        port map(
            clk         => tb_clk,
            reset       => tb_reset,
            ingresar    => tb_ingresar,
            clave_ok    => tb_clave_ok,
            bloqueado   => tb_lock,
            led_rojo    => tb_led_rojo,
            led_azul    => tb_led_azul,
            inc_intento => tb_inc_intento
        );

    U_BUSQUEDA : entity work.busqueda_clave
        port map(
            clave_ingresada => tb_clave_ingresada,
            enter           => tb_enter,
            correcta        => tb_correcta,
            incorrecta      => tb_incorrecta
        );

    U_CONTADOR : entity work.contador_intentos
        port map(
            clk   => tb_clk,
            reset => tb_reset,
            error => tb_inc_intento,  -- conectado a la FSM
            count => tb_count,
            lock  => tb_lock
        );
        
        
        
         process
    begin
        tb_clk <= '0'; wait for CLK_PERIOD / 2;
        tb_clk <= '1'; wait for CLK_PERIOD / 2;
    end process;

    -- ===== Estímulos =====
    process
    begin
    
     tb_reset <= '1';
        wait for 20 ns;
        tb_reset <= '0';
        wait for 10 ns;
        
        report ">>> INTENTO 1: clave incorrecta 0000";
        tb_clave_ingresada <= "0000";
        tb_bcd             <= "0000";  -- display muestra 0 intentos
        wait for 5 ns;
        tb_ingresar <= '1';
        tb_enter    <= '1';
        wait for 10 ns;
        tb_ingresar <= '0';
        tb_enter    <= '0';
        wait for 30 ns;
        
        report ">>> INTENTO 2: clave incorrecta 1111";
        tb_clave_ingresada <= "1111";
        tb_bcd             <= "0001";  -- display muestra 1 intento
        wait for 5 ns;
        tb_ingresar <= '1';
        tb_enter    <= '1';
        wait for 10 ns;
        tb_ingresar <= '0';
        tb_enter    <= '0';
        wait for 30 ns;
        
        report ">>> INTENTO 3: clave incorrecta 0101";
        tb_clave_ingresada <= "0101";
        tb_bcd             <= "0010";  -- display muestra 2 intentos
        wait for 5 ns;
        tb_ingresar <= '1';
        tb_enter    <= '1';
        wait for 10 ns;
        tb_ingresar <= '0';
        tb_enter    <= '0';
        wait for 30 ns;
        
        report ">>> INTENTO 4: clave incorrecta -> BLOQUEO";
        tb_clave_ingresada <= "0011";
        tb_bcd             <= "0011";  -- display muestra 3 intentos
        wait for 5 ns;
        tb_ingresar <= '1';
        tb_enter    <= '1';
        wait for 10 ns;
        tb_ingresar <= '0';
        tb_enter    <= '0';
        wait for 50 ns;
        -- En este punto tb_lock debería ser '1'
        report ">>> Sistema bloqueado, lock = " & STD_LOGIC'image(tb_lock);
        
         report ">>> RESET del sistema";
        tb_reset <= '1';
        wait for 20 ns;
        tb_reset <= '0';
        wait for 10 ns;
        
        report ">>> INTENTO CORRECTO para ALU: clave 1010";
        tb_clave_ingresada <= "1010";
        tb_bcd             <= "0000";
        wait for 5 ns;
        tb_ingresar <= '1';
        tb_enter    <= '1';
        wait for 10 ns;
        tb_ingresar <= '0';
        tb_enter    <= '0';
        wait for 30 ns;
        report ">>> led_azul = " & STD_LOGIC'image(tb_led_azul);
        report ">>> led_rojo = " & STD_LOGIC'image(tb_led_rojo);
        
         report ">>> INTENTO CORRECTO para busqueda_clave: clave 1011";
        tb_clave_ingresada <= "1011";
        tb_bcd             <= "0000";
        wait for 5 ns;
        tb_ingresar <= '1';
        tb_enter    <= '1';
        wait for 10 ns;
        tb_ingresar <= '0';
        tb_enter    <= '0';
        wait for 30 ns;
        report ">>> correcta   = " & STD_LOGIC'image(tb_correcta);
        report ">>> incorrecta = " & STD_LOGIC'image(tb_incorrecta);
        
         report ">>> Prueba BCD 7 segmentos";
        for i in 0 to 4 loop
            tb_bcd <= STD_LOGIC_VECTOR(to_unsigned(i, 4));
            wait for 20 ns;
            report "BCD=" & integer'image(i) &
                   "  seg=" & STD_LOGIC'image(tb_seg(6)) &
                              STD_LOGIC'image(tb_seg(5)) &
                              STD_LOGIC'image(tb_seg(4)) &
                              STD_LOGIC'image(tb_seg(3)) &
                              STD_LOGIC'image(tb_seg(2)) &
                              STD_LOGIC'image(tb_seg(1)) &
                              STD_LOGIC'image(tb_seg(0));
        end loop;
        
         report ">>> Simulacion finalizada";
        wait;
    end process;
end Behavioral;