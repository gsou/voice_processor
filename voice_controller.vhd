library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

use work.voice.all;

entity voice_controller is
  generic (NUMREGS : natural := 16;
           VOICES : natural := 4; -- Serial voices, allows different sounds
                                  -- (different instructions)
           POLY : natural := 1    -- Polyphony, computer in parallel (must use
                                  -- same instructions)
           );
  port (
    rst_i : in std_logic;
    clk_i : in std_logic;
    sample_i : in std_logic;

    -- Memory interface
    i_addr_o : out std_logic_vector(4 downto 0);
    i_data_i : in std_logic_vector(23 downto 0);

    -- Accept Midi commands (serial)
    midi_data_i : in std_logic_vector(7 downto 0);
    midi_rdy_i : in std_logic;

    busy_o : out std_logic;

    sample_o : out std_logic_vector(23 downto 0));

end entity;

architecture rtl of voice_controller is

  type state_t is (STDBY, STARTVOICE, WAITVOICE, MIXSAMPLE, NEXTVOICE, PUSH);
  signal state : state_t := STDBY;

  signal read1 : integer range 0 to NUMREGS - 1;

  -- Control interconnects
  signal ctrl_read1_bank : integer range 0 to NUMREGS - 1;
  signal ctrl_read2_bank : integer range 0 to NUMREGS - 1;
  signal ctrl_read1 : std_logic_vector(4 downto 0);
  signal ctrl_read2 : std_logic_vector(4 downto 0);
  signal ctrl_write : integer range 0 to NUMREGS - 1;
  signal ctrl_exec : std_logic_vector(2 downto 0);
  signal ctrl_mux   : std_logic_vector(3 downto 0);

  -- Master Statemachine IO (Serial voices)
  signal ctrl_bank : integer range 0 to VOICES - 1;
  signal inc_pc : std_logic;
  signal done : std_logic;
  signal start_proc : std_logic;
  signal instr : std_logic_vector(23 downto 0);
  signal program_counter : std_logic_vector(4 downto 0);
  signal last_sample : std_logic;

  -- Parallel voices arrays
  type midi_write_t is array (POLY-1 downto 0) of std_logic;
  signal midi_write : midi_write_t;

  type midi_tap_key_t is array (POLY-1 downto 0) of std_logic_vector(7 downto 0);
  signal midi_tap_key : midi_tap_key_t;

  -- Controller to special registers
  signal midi_key : midi_key_t(POLY-1 downto 0);
  signal midi_vel : midi_vel_t(POLY-1 downto 0);
  signal midi_mod : std_logic_vector(6 downto 0);

  type data_poly_t is array (POLY-1 downto 0) of std_logic_vector(23 downto 0);
  signal data_sample : data_poly_t;
  signal data_sample_cnt : data_poly_t;
  signal data_write : data_poly_t;
  signal data_read1 : data_poly_t;
  signal data_read1_imm : data_poly_t;
  signal data_read1_sp : data_poly_t;
  signal data_read2 : data_poly_t;
  signal data_read2_imm : data_poly_t;
  signal data_read2_sp : data_poly_t;

  -- Manage execution
  type exec_flags_t is array(POLY-1 downto 0) of std_logic_vector(1 downto 0);
  signal reg_enable    : std_logic_vector(POLY - 1 downto 0);
  signal reg_flags   : exec_flags_t;

  type sample_counter_t is array (VOICES-1 downto 0) of data_poly_t;
  signal sample_counter : sample_counter_t;

  signal note_set : note_bitfield_t(VOICES - 1 downto 0, POLY -1 downto 0);

  signal sample_mix : std_logic_vector(23 downto 0);

  signal sample_acc : std_logic_vector(23 downto 0);

  -- Mixing the parallel voices together
  -- TODO Make better mixer
  function mix_samples(signal samples : data_poly_t) return std_logic_vector is
    variable acc : std_logic_vector(23 downto 0) := (others => '0');
  begin
    for n in samples'range loop
      acc := std_logic_vector(unsigned(acc) + unsigned(samples(n)));
    end loop;
    return acc;
  end function;


begin

  instr <= i_data_i;
  i_addr_o <= program_counter;

  process (clk_i)
  begin
    if rising_edge(clk_i) then
      last_sample <= sample_i;
    end if;
  end process;


  -- Midi controller
  midi_ctrl : voice_midi generic map( VOICES => VOICES, POLY => POLY )
    port map (rst_i => rst_i, clk_i => clk_i, data_i => midi_data_i, ready_i => midi_rdy_i,
              midi_bank_i => ctrl_bank, midi_key_o => midi_key, midi_vel_o => midi_vel, midi_modwheel_o => midi_mod,
              note_set_o => note_set);

  -- Main statemachine
  process (rst_i, clk_i)
  begin
    if rst_i = '1' then
      state <= STDBY;
    elsif rising_edge(clk_i) then
      case state is
        when STDBY      => if sample_i = '1' and last_sample = '0' then state <= STARTVOICE; end if;
        when STARTVOICE => state <= WAITVOICE;
        when WAITVOICE  => if done = '1' then state <= MIXSAMPLE; end if;
        when MIXSAMPLE  => if ctrl_bank = VOICES - 1 then state <= PUSH; else state <= NEXTVOICE; end if;
        when NEXTVOICE  => state <= STARTVOICE;
        when PUSH       => state <= STDBY;
        when others => state <= STDBY;
      end case;
    end if;
  end process;

  sample_mix <= mix_samples(data_sample);

  -- Statemachine Data
  process (rst_i, clk_i)
  begin
    if rst_i = '1' then
      start_proc <= '0';
      ctrl_bank <= 0; -- Current voice
      sample_o <= (others => '0');
      for j in 0 to VOICES - 1 loop
        for i in 0 to POLY - 1 loop
          sample_counter(j)(i) <= (others => '0');
        end loop;
      end loop;
      program_counter <= (others => '0');
      busy_o <= '0';
      sample_acc <= (others => '0');
    elsif rising_edge(clk_i) then
      case state is
        when STDBY      => busy_o <= '0'; start_proc <= '0'; ctrl_bank <= 0; sample_acc <= (others => '0');
        when STARTVOICE => busy_o <= '1'; start_proc <= '1'; program_counter <= (others => '0');
        when WAITVOICE  => busy_o <= '1'; start_proc <= '0'; if inc_pc = '1' then program_counter <= std_logic_vector(unsigned(program_counter) + 1); end if;
        when MIXSAMPLE  => busy_o <= '1'; start_proc <= '0'; sample_acc <= std_logic_vector(unsigned(sample_acc) + unsigned(sample_mix));
        when NEXTVOICE  => busy_o <= '1'; start_proc <= '0'; program_counter <= (others => '0'); ctrl_bank <= ctrl_bank + 1 mod VOICES;
        when PUSH       => busy_o <= '1'; start_proc <= '0';
                           -- TODO Proper sample mix (With saturation)
                           sample_o <= sample_acc;
                           for j in 0 to VOICES - 1 loop
                             for i in 0 to POLY - 1 loop
                               sample_counter(j)(i) <= std_logic_vector(unsigned(sample_counter(j)(i)) + 1);
                             end loop;
                           end loop;
        when others     => busy_o <= '1'; start_proc <= '0'; ctrl_bank <= 0; sample_o <= (others => '0'); program_counter <= (others => '0');
      end case;

      -- Node Set
      for j in 0 to VOICES - 1 loop
        for i in 0 to POLY - 1 loop
          if note_set(j, i) = '1' then
            sample_counter(j)(i) <= (others => '0');
          end if;
        end loop;
      end loop;
    end if;
  end process;


  data_sample_cnt <= sample_counter(ctrl_bank);

  par_voices: for i in 0 to POLY-1 generate
    data_read1_imm(i) <= data_read1_sp(i) when ctrl_read1(4) = '1' else data_read1(i);
    data_read2_imm(i) <= data_read2_sp(i) when ctrl_read2(4) = '1' else data_read2(i);
    -- Special registers
    special_regs : voice_special port map (rst_i => rst_i, clk_i => clk_i, instr_i => instr, sc_i => data_sample_cnt(i),
                                           midi_key => midi_key(i), midi_vel => midi_vel(i), midi_mod => midi_mod,
                                           read1_addr_i => ctrl_read1(3 downto 0), read2_addr_i => ctrl_read2(3 downto 0),
                                           read1_data_o => data_read1_sp(i), read2_data_o => data_read2_sp(i));

    -- Register bank
    -- XXX Remove extra regs for serial?
    register_bank : voice_bank generic map (VOICES => VOICES, NUMREGS => 16, WIDTH_REGS => 24)
      port map (rst_i => rst_i, clk_i => clk_i, ctrl_bank_i => ctrl_bank, ctrl_read1_i => ctrl_read1_bank,
                ctrl_read2_i => ctrl_read2_bank, ctrl_write_i => ctrl_write, ctrl_write_en_i => reg_enable(i),
                data_write_i => data_write(i), data_read1_o => data_read1(i), data_read2_o => data_read2(i), data_sample_o => data_sample(i));

    flags : voice_flags port map (clk_i => clk_i, rst_i => rst_i, exec_i => ctrl_exec, flags_i => reg_flags(i), enable_o => reg_enable(i));

    alu: voice_data generic map (WIDTH_REGS => 24)
      port map (ctrl_mux_i => ctrl_mux, data_in1_i => data_read1_imm(i), data_in2_i => data_read2_imm(i), data_out_o => data_write(i), flags_o => reg_flags(i));
  end generate;

  ctrl_read1_bank <= to_integer(unsigned(ctrl_read1(3 downto 0)));
  ctrl_read2_bank <= to_integer(unsigned(ctrl_read2(3 downto 0)));

  processor : voice_processor generic map (NUMREGS => NUMREGS)
    port map (rst_i => rst_i, clk_i => clk_i, ctrl_mux_o => ctrl_mux, ctrl_read1_o => ctrl_read1,
              ctrl_read2_o => ctrl_read2, ctrl_write_o => ctrl_write, ctrl_inc_pc_o => inc_pc,
              ctrl_exec_cond_o => ctrl_exec, done_o => done, start_i => start_proc, instr_i => instr);

  -- TODO FX processor

end rtl;
