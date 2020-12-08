library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.numeric_std.ALL;

use work.voice.ALL;

entity voice_filter is
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
end entity;

architecture rtl of voice_filter is

  type regvoice_t is array(VOICES-1 downto 0) of std_logic_vector(N_BITS-1 downto 0);

  signal x_f : regvoice_t;
  signal highpass : std_logic_vector(N_BITS-1 downto 0);
  signal bandpass : std_logic_vector(N_BITS-1 downto 0);
  signal bandpass_f : regvoice_t;
  signal lowpass : std_logic_vector(N_BITS-1 downto 0);
  signal lowpass_f : regvoice_t;

  signal scaled_bandpass : std_logic_vector(2*N_BITS downto 0);
  signal scaled_highpass : std_logic_vector(2*N_BITS downto 0);
  signal scaled_lowpass : std_logic_vector(2*N_BITS downto 0);
begin

  process (clk_i, rst_i)
  begin
    if rst_i = '1' then
      for i in 0 to VOICES-1 loop
        bandpass_f(i) <= (others => '0');
        lowpass_f(i) <= (others => '0');
        x_f(i) <= (others => '0');
      end loop;
    elsif rising_edge(clk_i) then
      if srst_i = '1' then
        bandpass_f(ctrl_bank_i) <= (others => '0');
        lowpass_f(ctrl_bank_i) <= (others => '0');
        x_f(ctrl_bank_i) <= (others => '0');
      else
        if enable_i = '1' then
          x_f(ctrl_bank_i) <= x_i;
          bandpass_f(ctrl_bank_i) <= bandpass;
          lowpass_f(ctrl_bank_i) <= lowpass;
        end if;
      end if;
    end if;
  end process;


  scaled_bandpass <= std_logic_vector(signed('0' & filter_quality_i) * signed(bandpass_f(ctrl_bank_i)));
  highpass <= std_logic_vector( signed(x_f(ctrl_bank_i)) - signed(lowpass_f(ctrl_bank_i)) -  signed(scaled_bandpass(2*N_BITS-1 downto N_BITS)) ) ;

  scaled_highpass <= std_logic_vector(signed('0' & filter_freq_i) * signed(highpass));
  bandpass <= std_logic_vector( signed(scaled_highpass(2*N_BITS-1 downto N_BITS)) + signed(bandpass_f(ctrl_bank_i)) );

  scaled_lowpass <= std_logic_vector(signed('0' & filter_freq_i) * signed(bandpass));
  lowpass <= std_logic_vector( signed(scaled_lowpass(2*N_BITS-1 downto N_BITS)) + signed(lowpass_f(ctrl_bank_i)) );

  y_o <= lowpass_f(ctrl_bank_i);

end rtl;
