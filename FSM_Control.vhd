library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity FSM_Control is
    Port ( clk : in STD_LOGIC;
           reset : in STD_LOGIC;
           ingresar : in STD_LOGIC;
           clave_ok : in STD_LOGIC;
           bloqueado : in  STD_LOGIC;  -- señal del contador de intentos
            led_rojo : out STD_LOGIC;
            led_azul : out STD_LOGIC;
            inc_intento: out STD_LOGIC); 
end FSM_Control;

architecture Behavioral of FSM_Control is

 type estado_t is (IDLE, VERIFICANDO, CORRECTO, FALLIDO, BLOQUEADO_ST);
 signal estado : estado_t := IDLE;
 
begin
process(clk, reset)
    begin
        if reset = '1' then
            estado <= IDLE;
        elsif rising_edge(clk) then
            case estado is
                when IDLE =>
                    if ingresar = '1' and bloqueado = '0' then
                        estado <= VERIFICANDO;
                    elsif bloqueado = '1' then
                        estado <= BLOQUEADO_ST;
                    end if;

                when VERIFICANDO =>
                    if clave_ok = '1' then
                        estado <= CORRECTO;
                    else
                        estado <= FALLIDO;
                    end if;

                when CORRECTO =>
                    estado <= IDLE;   -- vuelve tras un ciclo

                when FALLIDO =>
                    estado <= IDLE;   -- incremento se registra en contador

                when BLOQUEADO_ST =>
                    if bloqueado = '0' then
                        estado <= IDLE;  -- desbloqueo automático
                    end if;
            end case;
        end if;
    end process;

-- Salidas combinacionales
    led_azul    <= '1' when estado = CORRECTO    else '0';
    led_rojo    <= '1' when estado = FALLIDO     else '0';
    inc_intento <= '1' when estado = FALLIDO     else '0';

end Behavioral;