library IEEE;
use IEEE.std_logic_1164.ALL;

use work.voice.ALL;

entity voice_midi is
  generic (VOICES : natural := 1; POLY : natural := 6); -- Polyphony of the midi controller
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
    -- TODO Reset
end entity;

architecture rtl of voice_midi is

  type channel_midi_key is array(VOICES - 1 downto 0) of midi_key_t(POLY-1 downto 0);
  type channel_midi_vel is array(VOICES - 1 downto 0) of midi_vel_t(POLY-1 downto 0);
  signal reg_midi_key : channel_midi_key;
  signal reg_midi_vel : channel_midi_vel;

  -- Midi decoder state machine
  type state_t is (CMD, VAL1, VAL2, EXEC, PROG);
  signal state : state_t;

  -- Midi command
  signal midi_command : std_logic_vector(7 downto 0);
  signal midi_value1 : std_logic_vector(7 downto 0);
  signal midi_value2 : std_logic_vector(7 downto 0);

  -- Algorithm to alloc next key. TODO Make it more usable (consider release)
  function which_to_alloc(signal taps : channel_midi_key) return integer is
  begin
    for j in 0 to VOICES - 1 loop
    for i in 0 to POLY-1 loop
      if taps(j)(i)(7) = '0' then
        return j * POLY + i;
      end if;
    end loop;
    end loop;
    return 0;
  end function;
  -- This patches the fact that my keyboard controller spams the keyon function
  function allow_to_alloc(signal taps : channel_midi_key; signal key : std_logic_vector(6 downto 0)) return boolean is
  begin
    for j in 0 to VOICES - 1 loop
    for i in 0 to POLY - 1 loop
      if taps(j)(i)(6 downto 0) = key and taps(j)(i)(7) = '1' then
        return false;
      end if;
    end loop;
    end loop;
    return true;
  end function;

  -- Reprogramming
  signal reprog_addr : std_logic_vector(7 downto 0);
  signal reprog_msb : std_logic_vector(7 downto 0);

begin

  midi_key_o <= reg_midi_key(midi_bank_i);
  midi_vel_o <= reg_midi_vel(midi_bank_i);

  -- State machine
  process (rst_i, clk_i)
  begin
    if rst_i = '1' then
      state <= CMD;
    elsif rising_edge(clk_i) then
      case state is
        when CMD  => if ready_i = '1' and data_i(7) = '1' then state <= VAL1; end if;
        when VAL1 => if ready_i = '1' then state <= VAL2; end if;
        when VAL2 => if ready_i = '1' then if midi_command = x"FF" then state <= PROG; else state <= EXEC; end if; end if;
        when EXEC => state <= CMD;
        when PROG => state <= CMD;
        when others => state <= CMD;
      end case;
    end if;
  end process;
  -- Data loading and command execution
  process (rst_i, clk_i)
    variable channel_sel : integer range 0 to POLY * VOICES - 1;
  begin
    if rst_i = '1' then
      midi_command <= (others => '0');
      midi_value1 <= (others => '0');
      midi_value2 <= (others => '0');
      midi_modwheel_o <= (others => '0');
      for j in 0 to VOICES-1 loop
        for i in 0 to POLY - 1 loop
          reg_midi_key(j)(i) <= (others => '0');
          reg_midi_vel(j)(i) <= (others => '0');
        end loop;
      end loop;
      reprog_addr <= (others => '0');
      reprog_msb <= (others => '0');
      inst_en_o <= '0';

    elsif rising_edge(clk_i) then
      for j in 0 to VOICES-1 loop
        for i in 0 to POLY - 1 loop
          note_set_o(j, i) <= '0';
        end loop;
      end loop;
      case state is
        when CMD => midi_command <= data_i; inst_en_o <= '0';
        when VAL1 => midi_value1 <= data_i;
        when VAL2 => midi_value2 <= data_i;
        when EXEC =>
          if midi_command = x"FE" then
            -- Progamming address
            reprog_addr <= midi_value1;
            reprog_msb <= midi_value2;
          elsif midi_command(7 downto 4) = "1001" then
            -- Note ON
            -- TODO Allow to use multiples voices for one note
            if allow_to_alloc(reg_midi_key, midi_value1(6 downto 0)) then
              channel_sel := which_to_alloc(reg_midi_key);
              reg_midi_key(channel_sel / POLY)(channel_sel rem POLY) <= midi_command(4) & midi_value1(6 downto 0);
              reg_midi_vel(channel_sel / POLY)(channel_sel rem POLY) <= midi_value2(6 downto 0);
              note_set_o(channel_sel / POLY, channel_sel rem POLY) <= '1';
            end if;
          elsif midi_command(7 downto 4) = "1000" then
            -- Note OFF
            for j in 0 to VOICES-1 loop
              for i in 0 to POLY - 1 loop
                if midi_value1(6 downto 0) = reg_midi_key(j)(i)(6 downto 0) then
                  reg_midi_key(j)(i) <= midi_command(4) & midi_value1(6 downto 0);
                  reg_midi_vel(j)(i) <= midi_value2(6 downto 0);
                end if;
              end loop;
            end loop;
          elsif midi_command(7 downto 4) = "1011" then
            -- Controller, only modwheel is supported
            if midi_value1 = "00000001" then
              midi_modwheel_o <= midi_value2(6 downto 0);
            end if;
          end if;
        when PROG =>
          inst_en_o <= '1';
          inst_addr_o <= reprog_addr;
          inst_data_o <= reprog_msb & midi_value1 & midi_value2;
        when others =>
          midi_command <= (others => '0');
          midi_value1 <= (others => '0');
          midi_value2 <= (others => '0');
          midi_modwheel_o <= (others => '0');
      end case;
    end if;
  end process;

end rtl;
