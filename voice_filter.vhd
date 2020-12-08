library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use work.voice.ALL;

entity voice_filter is
  generic (N_BITS : natural := 24);
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;
    srst_i : std_logic;

    enable_i : std_logic;
    filter_freq_i : in std_logic_vector(N_BITS-1 downto 0);
    filter_quality_i : in std_logic_vector(N_BITS-1 downto 0);

    x_i : in std_logic_vector(N_BITS-1 downto 0);
    y_o : out std_logic_vector(N_BITS-1 downto 0)
);
end entity;

architecture rtl of voice_filter is

  signal x_f : std_logic_vector(N_BITS-1 downto 0);
  signal highpass : std_logic_vector(N_BITS-1 downto 0);
  signal bandpass : std_logic_vector(N_BITS-1 downto 0);
  signal bandpass_f : std_logic_vector(N_BITS-1 downto 0);
  signal lowpass : std_logic_vector(N_BITS-1 downto 0);
  signal lowpass_f : std_logic_vector(N_BITS-1 downto 0);

  signal scaled_bandpass : std_logic_vector(2*N_BITS - 1 downto 0);
  signal scaled_highpass : std_logic_vector(2*N_BITS - 1 downto 0);
begin

  process (clk_i, rst_i)
  begin
    if rst_i = '1' then
      bandpass_f <= (others => '0');
      lowpass_f <= (others => '0');
      x_f <= (others => '0');
    elsif rising_edge(clk_i) then
      if srst_i = '1' then
        bandpass_f <= (others => '0');
        lowpass_f <= (others => '0');
        x_f <= (others => '0');
      else
        if enable_i = '1' then
          x_f <= x_i;
          bandpass_f <= bandpass;
          lowpass_f <= lowpass;
        end if;
      end if;
    end if;
  end process;


  scaled_bandpass <= std_logic_vector(signed(filter_quality_i) * signed(bandpass_f));
  highpass <= std_logic_vector( signed(x_f) - signed(lowpass_f) -  signed(scaled_bandpass(2*N_BITS-2 downto N_BITS-1)) ) ;

  scaled_highpass <= std_logic_vector(signed(filter_freq_i) * signed(highpass));
  bandpass <= std_logic_vector( signed(scaled_highpass(2*N_BITS-2 downto N_BITS-1)) + signed(bandpass_f) );

  scaled_lowpass <= std_logic_vector(signed(filter_freq_i) * signed(bandpass));
  lowpass <= std_logic_vector( signed(scaled_lowpass(2*N_BITS-2 downto N_BITS-1)) + signed(lowpass_f) );

  y_o <= lowpass_f;

end rtl;
