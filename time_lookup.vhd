library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

use work.voice.all;

entity time_lookup is
  port (
    lookup_i : in std_logic_vector(5 downto 0);
    der_o : out std_logic_vector(11 downto 0);
    time_o : out std_logic_vector(23 downto 0));
end entity;

architecture rtl of time_lookup is

  signal der : std_logic_vector(11 downto 0);
begin

  der_o <= der;
  der <= std_logic_vector(unsigned(lookup_i) * unsigned(lookup_i));
  time_o <= "000000" & der & "000000";

end rtl;
