-- ============================================================
--  COMPONENTE 10: TOP LEVEL — CHAPA_CPU (Integración completa)
--  Archivo : 10_TopLevel.vhd
--
--  Función  : Instancia y conecta todos los componentes:
--               01_ALU, 02_Acumulador, 03_GPR, 04_PC,
--               05_MAR, 06_Memoria, 07_Decodificador,
--               08_UnidadControl, 09_Puertos
--
--  Este es el archivo que se sintetiza en el FPGA.
--  Los pines de la entidad corresponden 1:1 con los pines
--  físicos del FPGA definidos en el archivo .xdc (constraints).
--
--  Pines físicos del FPGA:
--    CLK         → Oscilador del FPGA (ej: 100MHz Basys3)
--    RESET       → Botón físico del FPGA (o pin GPIO al ESP32)
--    ENABLE      → Pin GPIO del ESP32
--    DATA_IN     → 8 pines GPIO del ESP32 (puerto paralelo)
--    DATA_READY  → 1 pin GPIO del ESP32 (handshake)
--    DATA_OUT    → 8 pines GPIO al ESP32 (puerto paralelo)
--    CHAPA_OPEN  → Pin GPIO a transistor/relé de la chapa
--    CHAPA_LED   → 2 pines GPIO a LEDs (verde/rojo)
--    LOCKED      → Pin GPIO al ESP32 (avisa bloqueo)
--    ATTEMPTS_LEFT → 2 pines GPIO al ESP32 (intentos restantes)
--
--  Constantes globales:
--    MASTER_KEY  = 0xB5 ("10110101")
--    STORED_PASS = 0xE3 ("11100011") → 0x56 XOR 0xB5
--    Código correcto = 0x56 ("01010110") = 86 decimal
--    Máx intentos    = 3
-- ============================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity CHAPA_CPU is
    Port (
        -- Control global
        CLK           : in  STD_LOGIC;
        RESET         : in  STD_LOGIC;
        ENABLE        : in  STD_LOGIC;

        -- Interfaz con ESP32 (entrada)
        DATA_IN       : in  STD_LOGIC_VECTOR(7 downto 0);
        DATA_READY    : in  STD_LOGIC;

        -- Interfaz con ESP32 (salida)
        DATA_OUT      : out STD_LOGIC_VECTOR(7 downto 0);
        ATTEMPTS_LEFT : out STD_LOGIC_VECTOR(1 downto 0);
        LOCKED        : out STD_LOGIC;

        -- Salidas físicas hacia chapa y LEDs
        CHAPA_OPEN    : out STD_LOGIC;
        CHAPA_LED     : out STD_LOGIC_VECTOR(1 downto 0)
    );
end CHAPA_CPU;

architecture RTL of CHAPA_CPU is

    -- ============================================================
    -- CLAVE MAESTRA (XOR con el código de acceso)
    -- Código correcto = 0x56 | MASTER_KEY = 0xB5 | 0x56 XOR 0xB5 = 0xE3
    -- ============================================================
    constant MASTER_KEY : STD_LOGIC_VECTOR(7 downto 0) := "10110101"; -- 0xB5

    -- ============================================================
    -- SEÑALES INTERNAS (buses que conectan los componentes)
    -- ============================================================

    -- Bus de datos principal
    signal s_data_in_buf  : STD_LOGIC_VECTOR(7 downto 0);

    -- PC
    signal s_pc_out       : STD_LOGIC_VECTOR(7 downto 0);
    signal s_pc_inc       : STD_LOGIC;
    signal s_pc_load      : STD_LOGIC;
    signal s_pc_din       : STD_LOGIC_VECTOR(7 downto 0);

    -- MAR
    signal s_mar_addr     : STD_LOGIC_VECTOR(7 downto 0);
    signal s_mar_load     : STD_LOGIC;
    signal s_mar_din      : STD_LOGIC_VECTOR(7 downto 0);

    -- Instruction Register (IR) — implementado como señal interna
    signal s_ir           : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal s_ir_load      : STD_LOGIC;

    -- Memoria
    signal s_mem_data_out : STD_LOGIC_VECTOR(7 downto 0);
    signal s_mem_wr       : STD_LOGIC;

    -- Decodificador
    signal s_opcode       : STD_LOGIC_VECTOR(3 downto 0);
    signal s_operand      : STD_LOGIC_VECTOR(3 downto 0);
    signal s_alu_op       : STD_LOGIC_VECTOR(1 downto 0);

    -- ALU
    signal s_alu_result   : STD_LOGIC_VECTOR(7 downto 0);
    signal s_alu_flag_z   : STD_LOGIC;
    signal s_alu_flag_c   : STD_LOGIC;

    -- Acumulador
    signal s_acc_data     : STD_LOGIC_VECTOR(7 downto 0);
    signal s_acc_load     : STD_LOGIC;
    signal s_acc_src      : STD_LOGIC_VECTOR(1 downto 0);
    signal s_acc_din      : STD_LOGIC_VECTOR(7 downto 0);

    -- GPR
    signal s_gpr_data_out : STD_LOGIC_VECTOR(7 downto 0);
    signal s_gpr_r2       : STD_LOGIC_VECTOR(7 downto 0);
    signal s_gpr_wr       : STD_LOGIC;
    signal s_gpr_wsel     : STD_LOGIC_VECTOR(1 downto 0);
    signal s_gpr_rsel     : STD_LOGIC_VECTOR(1 downto 0);

    -- Unidad de Control
    signal s_out_en       : STD_LOGIC;
    signal s_access_ok    : STD_LOGIC;
    signal s_locked       : STD_LOGIC;
    signal s_chapa_open   : STD_LOGIC;
    signal s_chapa_led    : STD_LOGIC_VECTOR(1 downto 0);

    -- ============================================================
    -- DECLARACIÓN DE COMPONENTES
    -- ============================================================

    component ALU is
        Port (
            A      : in  STD_LOGIC_VECTOR(7 downto 0);
            B      : in  STD_LOGIC_VECTOR(7 downto 0);
            OP     : in  STD_LOGIC_VECTOR(1 downto 0);
            RESULT : out STD_LOGIC_VECTOR(7 downto 0);
            FLAG_Z : out STD_LOGIC;
            FLAG_C : out STD_LOGIC
        );
    end component;

    component Acumulador is
        Port (
            CLK      : in  STD_LOGIC;
            RESET    : in  STD_LOGIC;
            ENABLE   : in  STD_LOGIC;
            LOAD     : in  STD_LOGIC;
            DATA_IN  : in  STD_LOGIC_VECTOR(7 downto 0);
            DATA_OUT : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    component GPR is
        Port (
            CLK      : in  STD_LOGIC;
            RESET    : in  STD_LOGIC;
            ENABLE   : in  STD_LOGIC;
            WR_EN    : in  STD_LOGIC;
            WR_SEL   : in  STD_LOGIC_VECTOR(1 downto 0);
            RD_SEL   : in  STD_LOGIC_VECTOR(1 downto 0);
            DATA_IN  : in  STD_LOGIC_VECTOR(7 downto 0);
            DATA_OUT : out STD_LOGIC_VECTOR(7 downto 0);
            R2_OUT   : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    component PC is
        Port (
            CLK     : in  STD_LOGIC;
            RESET   : in  STD_LOGIC;
            ENABLE  : in  STD_LOGIC;
            INC     : in  STD_LOGIC;
            LOAD    : in  STD_LOGIC;
            DATA_IN : in  STD_LOGIC_VECTOR(7 downto 0);
            PC_OUT  : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    component MAR is
        Port (
            CLK      : in  STD_LOGIC;
            RESET    : in  STD_LOGIC;
            ENABLE   : in  STD_LOGIC;
            LOAD     : in  STD_LOGIC;
            ADDR_IN  : in  STD_LOGIC_VECTOR(7 downto 0);
            ADDR_OUT : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    component Memoria is
        Port (
            CLK      : in  STD_LOGIC;
            RESET    : in  STD_LOGIC;
            ADDR     : in  STD_LOGIC_VECTOR(7 downto 0);
            DATA_IN  : in  STD_LOGIC_VECTOR(7 downto 0);
            WR_EN    : in  STD_LOGIC;
            DATA_OUT : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    component Decodificador is
        Port (
            IR      : in  STD_LOGIC_VECTOR(7 downto 0);
            OPCODE  : out STD_LOGIC_VECTOR(3 downto 0);
            OPERAND : out STD_LOGIC_VECTOR(3 downto 0);
            ALU_OP  : out STD_LOGIC_VECTOR(1 downto 0)
        );
    end component;

    component UnidadControl is
        Port (
            CLK        : in  STD_LOGIC;
            RESET      : in  STD_LOGIC;
            ENABLE     : in  STD_LOGIC;
            DATA_READY : in  STD_LOGIC;
            OPCODE     : in  STD_LOGIC_VECTOR(3 downto 0);
            OPERAND    : in  STD_LOGIC_VECTOR(3 downto 0);
            ACC_DATA   : in  STD_LOGIC_VECTOR(7 downto 0);
            R2_DATA    : in  STD_LOGIC_VECTOR(7 downto 0);
            PC_OUT     : in  STD_LOGIC_VECTOR(7 downto 0);
            FLAG_Z     : in  STD_LOGIC;
            FLAG_C     : in  STD_LOGIC;
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
    end component;

    component Puertos is
        Port (
            CLK           : in  STD_LOGIC;
            RESET         : in  STD_LOGIC;
            ENABLE        : in  STD_LOGIC;
            DATA_IN       : in  STD_LOGIC_VECTOR(7 downto 0);
            DATA_READY    : in  STD_LOGIC;
            ACC_DATA      : in  STD_LOGIC_VECTOR(7 downto 0);
            R2_DATA       : in  STD_LOGIC_VECTOR(7 downto 0);
            ACCESS_OK     : in  STD_LOGIC;
            LOCKED_IN     : in  STD_LOGIC;
            CHAPA_OPEN_IN : in  STD_LOGIC;
            CHAPA_LED_IN  : in  STD_LOGIC_VECTOR(1 downto 0);
            OUT_EN_IN     : in  STD_LOGIC;
            DATA_OUT      : out STD_LOGIC_VECTOR(7 downto 0);
            DATA_IN_BUF   : out STD_LOGIC_VECTOR(7 downto 0);
            CHAPA_OPEN    : out STD_LOGIC;
            CHAPA_LED     : out STD_LOGIC_VECTOR(1 downto 0);
            LOCKED        : out STD_LOGIC;
            ATTEMPTS_LEFT : out STD_LOGIC_VECTOR(1 downto 0)
        );
    end component;

begin

    -- ============================================================
    -- MUX DE ENTRADA AL ACUMULADOR
    -- Selecciona la fuente del dato según ACC_SRC:
    --   "00" → DATA_IN_BUF  (código del ESP32)
    --   "01" → ALU result   (resultado XOR/ADD)
    --   "10" → Memoria RAM  (LOAD_MAR)
    --   "11" → GPR          (lectura de registro)
    -- ============================================================
    s_acc_din <= s_data_in_buf    when s_acc_src = "00" else
                 s_alu_result     when s_acc_src = "01" else
                 s_mem_data_out   when s_acc_src = "10" else
                 s_gpr_data_out;

    -- ============================================================
    -- INSTRUCTION REGISTER (IR)
    -- Registro sencillo: carga desde memoria cuando IR_LOAD activo
    -- ============================================================
    IR_REG: process(CLK)
    begin
        if rising_edge(CLK) then
            if RESET = '1' then
                s_ir <= (others => '0');
            elsif ENABLE = '1' and s_ir_load = '1' then
                s_ir <= s_mem_data_out;  -- IR ← ROM[PC]
            end if;
        end if;
    end process;

    -- ============================================================
    -- INSTANCIAS DE COMPONENTES
    -- ============================================================

    U_ALU: ALU
        port map (
            A      => s_acc_data,
            B      => MASTER_KEY,    -- Operando B siempre es la clave XOR
            OP     => s_alu_op,
            RESULT => s_alu_result,
            FLAG_Z => s_alu_flag_z,
            FLAG_C => s_alu_flag_c
        );

    U_ACC: Acumulador
        port map (
            CLK      => CLK,
            RESET    => RESET,
            ENABLE   => ENABLE,
            LOAD     => s_acc_load,
            DATA_IN  => s_acc_din,
            DATA_OUT => s_acc_data
        );

    U_GPR: GPR
        port map (
            CLK      => CLK,
            RESET    => RESET,
            ENABLE   => ENABLE,
            WR_EN    => s_gpr_wr,
            WR_SEL   => s_gpr_wsel,
            RD_SEL   => s_gpr_rsel,
            DATA_IN  => s_acc_data,  -- GPR siempre recibe del ACC
            DATA_OUT => s_gpr_data_out,
            R2_OUT   => s_gpr_r2
        );

    U_PC: PC
        port map (
            CLK     => CLK,
            RESET   => RESET,
            ENABLE  => ENABLE,
            INC     => s_pc_inc,
            LOAD    => s_pc_load,
            DATA_IN => s_pc_din,
            PC_OUT  => s_pc_out
        );

    U_MAR: MAR
        port map (
            CLK      => CLK,
            RESET    => RESET,
            ENABLE   => ENABLE,
            LOAD     => s_mar_load,
            ADDR_IN  => s_mar_din,
            ADDR_OUT => s_mar_addr
        );

    U_MEM: Memoria
        port map (
            CLK      => CLK,
            RESET    => RESET,
            ADDR     => s_mar_addr,
            DATA_IN  => s_acc_data,  -- escritura siempre desde ACC
            WR_EN    => s_mem_wr,
            DATA_OUT => s_mem_data_out
        );

    U_DEC: Decodificador
        port map (
            IR      => s_ir,
            OPCODE  => s_opcode,
            OPERAND => s_operand,
            ALU_OP  => s_alu_op
        );

    U_UC: UnidadControl
        port map (
            CLK        => CLK,
            RESET      => RESET,
            ENABLE     => ENABLE,
            DATA_READY => DATA_READY,
            OPCODE     => s_opcode,
            OPERAND    => s_operand,
            ACC_DATA   => s_acc_data,
            R2_DATA    => s_gpr_r2,
            PC_OUT     => s_pc_out,
            FLAG_Z     => s_alu_flag_z,
            FLAG_C     => s_alu_flag_c,
            PC_INC     => s_pc_inc,
            PC_LOAD    => s_pc_load,
            PC_DIN     => s_pc_din,
            MAR_LOAD   => s_mar_load,
            MAR_DIN    => s_mar_din,
            IR_LOAD    => s_ir_load,
            ACC_LOAD   => s_acc_load,
            ACC_SRC    => s_acc_src,
            MEM_WR     => s_mem_wr,
            GPR_WR     => s_gpr_wr,
            GPR_WSEL   => s_gpr_wsel,
            GPR_RSEL   => s_gpr_rsel,
            OUT_EN     => s_out_en,
            ACCESS_OK  => s_access_ok,
            LOCKED     => s_locked,
            CHAPA_OPEN => s_chapa_open,
            CHAPA_LED  => s_chapa_led
        );

    U_PORT: Puertos
        port map (
            CLK           => CLK,
            RESET         => RESET,
            ENABLE        => ENABLE,
            DATA_IN       => DATA_IN,
            DATA_READY    => DATA_READY,
            ACC_DATA      => s_acc_data,
            R2_DATA       => s_gpr_r2,
            ACCESS_OK     => s_access_ok,
            LOCKED_IN     => s_locked,
            CHAPA_OPEN_IN => s_chapa_open,
            CHAPA_LED_IN  => s_chapa_led,
            OUT_EN_IN     => s_out_en,
            DATA_OUT      => DATA_OUT,
            DATA_IN_BUF   => s_data_in_buf,
            CHAPA_OPEN    => CHAPA_OPEN,
            CHAPA_LED     => CHAPA_LED,
            LOCKED        => LOCKED,
            ATTEMPTS_LEFT => ATTEMPTS_LEFT
        );

end RTL;