library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity RLE_encoder is
  port (
    clk            : in  std_logic;
    reset          : in  std_logic;
    start          : in  std_logic;
    data_in        : in  std_logic_vector(7 downto 0);
    data_out       : out std_logic_vector(15 downto 0);
    done           : out std_logic;
    reduced_length : out unsigned(7 downto 0)
  );
end entity;

architecture arch of RLE_encoder is

 
  type mem_t is array (0 to 63) of std_logic_vector(7 downto 0);
  signal mem : mem_t;

  
  type zigzag_t is array (0 to 63) of integer range 0 to 63;
  constant zigzag_order : zigzag_t := (
    0, 1, 8,
    16, 9, 2,
    3, 10, 17, 24,
    32, 25, 18, 11, 4,
    5, 12, 19, 26, 33, 40,
    48, 41, 34, 27, 20, 13, 6,
    7, 14, 21, 28, 35, 42, 49, 56,
    57, 50, 43, 36, 29, 22, 15,
    23, 30, 37, 44, 51, 58,
    59, 52, 45, 38, 31,
    39, 46, 53, 60,
    61, 54, 47,
    55, 62,
    63
  );

  type rle_t is array (0 to 63) of std_logic_vector(15 downto 0);
  signal rle_buffer : rle_t;

  signal load_cnt      : integer range 0 to 63 := 0;
  signal encode_cnt    : integer range 0 to 63 := 0;
  signal output_cnt    : integer range 0 to 63 := 0;
  signal rle_index     : integer range 0 to 63 := 0;
  signal count_sig     : integer range 1 to 64 := 1;
  signal state         : integer range 0 to 3 := 0;  
  signal reduced_length_int : unsigned(7 downto 0) := (others => '0');

begin
  
  reduced_length <= reduced_length_int;

 
  process(clk, reset)
  begin
    if reset = '1' then
      load_cnt      <= 0;
      encode_cnt    <= 0;
      output_cnt    <= 0;
      rle_index     <= 0;
      count_sig     <= 1;
      state         <= 0;
      done          <= '0';
      data_out      <= (others => '0');
      reduced_length_int <= (others => '0');

    elsif rising_edge(clk) then
      case state is

        when 0 =>  
    
          done <= '0';
          if start = '1' then
            mem(load_cnt) <= data_in;
            if load_cnt = 63 then
              load_cnt   <= 0;
              encode_cnt <= 1;   
              rle_index  <= 0;
              count_sig  <= 1;    
              state      <= 1;   
            else
              load_cnt <= load_cnt + 1;
            end if;
          end if;

        when 1 =>  
  if encode_cnt < 63 then
   
    if mem(zigzag_order(encode_cnt)) = mem(zigzag_order(encode_cnt - 1)) then
      count_sig <= count_sig + 1;
    else
      rle_buffer(rle_index) <= std_logic_vector(to_unsigned(count_sig, 8)) &
                               mem(zigzag_order(encode_cnt - 1));
      rle_index <= rle_index + 1;
      count_sig <= 1;
    end if;
    encode_cnt <= encode_cnt + 1;

  elsif encode_cnt = 63 then
    
    if mem(zigzag_order(63)) = mem(zigzag_order(62)) then
      
      rle_buffer(rle_index) <= std_logic_vector(to_unsigned(count_sig + 1, 8)) &
                               mem(zigzag_order(63));
      reduced_length_int <= to_unsigned(rle_index + 1, 8);
    else
    
      rle_buffer(rle_index) <= std_logic_vector(to_unsigned(count_sig, 8)) &
                               mem(zigzag_order(62));
      rle_index <= rle_index + 1;
      rle_buffer(rle_index) <= std_logic_vector(to_unsigned(1, 8)) &
                               mem(zigzag_order(63));
      reduced_length_int <= to_unsigned(rle_index + 1, 8);
    end if;
    output_cnt <= 0;
    state <= 2; 
  end if;

        
        when 2 =>  
       
          done <= '1'; 
          data_out <= rle_buffer(output_cnt);

          if output_cnt = (to_integer(reduced_length_int) - 1) then
            state <= 3;  
          else
            output_cnt <= output_cnt + 1;
          end if;

   
        when 3 =>
    
          done <= '1';
          

        when others =>
          null;
      end case;
    end if;
  end process;

end architecture;
