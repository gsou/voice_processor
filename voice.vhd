library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

package voice is

  type note_bitfield_t is array (natural range <>, natural range <>) of std_logic;
  type midi_key_t is array (natural range <>) of std_logic_vector(7 downto 0);
  type midi_vel_t is array (natural range <>) of std_logic_vector(6 downto 0);

  component voice_controller is
    generic (NUMREGS : natural := 16;
             VOICES : natural := 1);
    port (
      rst_i : in std_logic;
      clk_i : in std_logic;
      sample_i : in std_logic;
      sample_o : out std_logic_vector(23 downto 0);
      -- Memory interface
      i_addr_o : out std_logic_vector(7 downto 0);
      i_data_i : in std_logic_vector(23 downto 0);
      i_wr_data_o : out std_logic_vector(23 downto 0);
      i_wr_addr_o : out std_logic_vector(7 downto 0);
      i_wr_en_o : out std_logic;
      -- Accept Midi commands
      midi_ev_i : in std_logic;
      midi_rel_i : in std_logic;
      midi_key_i : in std_logic_vector(6 downto 0);
      midi_vel_i : in std_logic_vector(6 downto 0));
  end component;

  component voice_bank is
    generic (VOICES : natural := 4;
             NUMREGS : natural := 16;
             WIDTH_REGS : natural := 24);
    port (
      rst_i : in std_logic; -- Active high reset
      clk_i : in std_logic;
      -- Control ports
      ctrl_bank_i  : in integer range 0 to VOICES - 1;
      ctrl_read1_i : in integer range 0 to NUMREGS - 1;
      ctrl_read2_i : in integer range 0 to NUMREGS - 1;
      ctrl_write_i : in integer range 0 to NUMREGS - 1;
      ctrl_write_en_i : in std_logic;
      -- Data ports
      data_write_i : in  std_logic_vector(WIDTH_REGS   - 1 downto 0);
      data_read1_o : out std_logic_vector(WIDTH_REGS   - 1 downto 0);
      data_read2_o : out std_logic_vector(WIDTH_REGS   - 1 downto 0);
      data_write_o : out std_logic_vector(WIDTH_REGS   - 1 downto 0);
      data_sample_o : out std_logic_vector(WIDTH_REGS - 1 downto 0)
      );
  end component;

  component voice_data is
    generic (WIDTH_REGS : natural := 24);
    port(
      -- Control ports
      ctrl_mux_i : in std_logic_vector(3 downto 0);
      -- Data ports
      data_in1_i : in std_logic_vector(WIDTH_REGS - 1 downto 0);
      data_in2_i : in std_logic_vector(WIDTH_REGS - 1 downto 0);
      data_out_o : out std_logic_vector(WIDTH_REGS - 1 downto 0);

      data_filter_i: in std_logic_vector(WIDTH_REGS - 1 downto 0);

      flags_o : out std_logic_vector(1 downto 0));
  end component;


  component voice_processor is
    generic (NUMREGS : natural := 16);
    port (
      rst_i : in std_logic;
      clk_i : in std_logic;
      -- Control

      ctrl_mux_o : out std_logic_vector(3 downto 0);
      ctrl_read1_o : out std_logic_vector(4 downto 0);
      ctrl_read2_o : out std_logic_vector(4 downto 0);
      ctrl_write_o : out integer range 0 to NUMREGS - 1;
      ctrl_exec_cond_o : out std_logic_vector(2 downto 0);

      ctrl_inc_pc_o : out std_logic;
      done_o : out std_logic;
      -- Data
      start_i : in std_logic;
      instr_i : in std_logic_vector(23 downto 0));
  end component;

  component midi_lookup is
    port (
      midi_i : in std_logic_vector(6 downto 0);
      counter_i : in unsigned(23 downto 0);
      freq_o : out std_logic_vector(23 downto 0)
      );
  end component;

  component dac is
    generic (SAMPLE_WIDTH : natural := 24);
    port (rst_i : in std_logic;
          clk_i : in std_logic;
          sample_i : in std_logic_vector(SAMPLE_WIDTH - 1 downto 0);
          dac_o : out std_logic);
  end component;

  -- Special Register Bank
  component voice_special is
    port (
    clk_i : in std_logic;
    rst_i : in std_logic;

    -- Passthrough
    instr_i : in std_logic_vector(23 downto 0);
    sc_i : in std_logic_vector(23 downto 0);
    -- Write port (for midi)
    midi_key : in std_logic_vector(7 downto 0);
    midi_vel : in std_logic_vector(6 downto 0);
    midi_mod : in std_logic_vector(6 downto 0);

    -- Read port A
    read1_addr_i : in std_logic_vector(3 downto 0);
    read1_data_o : out std_logic_vector(23 downto 0);

    -- Read port B
    read2_addr_i : in std_logic_vector(3 downto 0);
    read2_data_o : out std_logic_vector(23 downto 0));
  end component;

  component voice_midi is
    generic (VOICES : natural := 1; POLY : natural := 8); -- Polyphony of the midi controller
    port (
      rst_i : in std_logic;
      clk_i : in std_logic;

      -- Serial data input
      data_i : in std_logic_vector(7 downto 0);
      ready_i : in std_logic;

      -- Midi Reprogrammer
      inst_data_o : out std_logic_vector(23 downto 0);
      inst_addr_o : out std_logic_vector(7 downto 0);
      inst_en_o : out std_logic;

      -- TODO Note disable from controller, for now its just on release
      -- TODO Allow sample counter to be used for enveloppes by reseting it on
      -- new notes

      -- Polyphony midi status
      midi_bank_i : in integer range 0 to VOICES - 1; -- Voice selector
      midi_key_o : out midi_key_t(POLY-1 downto 0);
      midi_vel_o : out midi_vel_t(POLY-1 downto 0);
      midi_modwheel_o : out std_logic_vector(6 downto 0);

      -- Note Set and Reset controller
      note_set_o : out note_bitfield_t(VOICES-1 downto 0, POLY-1 downto 0));
  end component;

  component sine_lookup is
    port (
      counter_i : in unsigned(7 downto 0);
      freq_o : out std_logic_vector(23 downto 0)
      );
  end component;

  component voice_flags is
    port (
      clk_i : in std_logic;
      rst_i : in std_logic;

      exec_i : in std_logic_vector(2 downto 0);
      flags_i : in std_logic_vector(1 downto 0);
      enable_o : out std_logic

      );
  end component;

  component time_lookup is
    port (
      lookup_i : in std_logic_vector(5 downto 0);
      der_o : out std_logic_vector(11 downto 0);
      time_o : out std_logic_vector(23 downto 0));
  end component;

component voice_filter is
  generic (N_BITS : natural := 24; VOICES : natural := 1);
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    srst_i : std_logic;

    ctrl_bank_i  : in integer range 0 to VOICES - 1;
    enable_i : std_logic;
    filter_freq_i : in std_logic_vector(N_BITS-1 downto 0);
    filter_quality_i : in std_logic_vector(N_BITS-1 downto 0);

    x_i : in std_logic_vector(N_BITS-1 downto 0);
    y_o : out std_logic_vector(N_BITS-1 downto 0)
);
end component;

end voice;
