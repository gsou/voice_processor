#!/usr/bin/env python3

from math import sin, pi

# TODO Optimize with quarterwave
with open("sine_lookup.vhd", 'w') as f:
    f.write("""

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

-- Sine lookup table. Input is 0 to 2^24-1 => 0 to 2pi
-- Output is -2^23 to 2^23-1 => -1 to ~1
entity sine_lookup is
  port (
    counter_i : in unsigned(7 downto 0);
    freq_o : out std_logic_vector(23 downto 0)
    );
end entity;

architecture rtl of sine_lookup is

  type LUT_t is array (256 downto 0) of signed(23 downto 0);

  signal LUT : LUT_t;

begin

    freq_o <= std_logic_vector(LUT(to_integer(unsigned(counter_i))));

""")

    for i in range(256):
        f.write("    LUT(" + str(i) + ") <= to_signed(" + str(int(2**23 * sin(2*pi * i/256))) + ", 24);\n");

    f.write("end rtl;\n")
