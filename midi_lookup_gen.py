#!/usr/bin/env python3

with open("midi_lookup.vhd", 'w') as f:
    f.write("""

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

-- Special lookup table based saw oscllator used to feed other oscillators. It
-- takes a midi frequency and a counter value and outputs the index value for
-- the oscillator
entity midi_lookup is
  port (
    midi_i : in std_logic_vector(6 downto 0);
    counter_i : in unsigned(23 downto 0);
    freq_o : out std_logic_vector(23 downto 0)
    );
end entity;

architecture rtl of midi_lookup is

  type LUT_t is array (127 downto 0) of unsigned(23 downto 0);

  signal LUT : LUT_t;
  signal freq_all : unsigned(47 downto 0);

begin

    freq_all <= counter_i * LUT(to_integer(unsigned(midi_i)));
    freq_o <= std_logic_vector(freq_all(23 downto 0));
""")

    samplerate = 44100


    for i in range(128):
        freq = (440 / 32) * (2 ** ((i - 9) / 12))
        v = 2**24 / samplerate * freq
        f.write("    LUT(" + str(i) + ") <= to_unsigned(" + str(int(v)) + ", 24);\n")

    f.write("end rtl;\n")
