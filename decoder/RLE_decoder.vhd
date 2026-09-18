library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity RLE_decoder is
  port (
    clk            : in  std_logic;
    reset          : in  std_logic;
    data_in        : in  std_logic_vector(15 downto 0);
    start          : in  std_logic;
    reduced_length : in  unsigned(7 downto 0);
    data_out       : out std_logic_vector(7 downto 0);
    done           : out std_logic
  );
end entity;

architecture rtl of RLE_decoder is
  
  type mem_t is array (0 to 63) of std_logic_vector(7 downto 0);
  signal mem : mem_t;
  
  type rle_t is array (0 to 255) of std_logic_vector(15 downto 0);
  signal rle_buffer : rle_t;
  
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
  
  signal input_cnt    : integer range 0 to 255 := 0;
  signal rle_idx      : integer range 0 to 255 := 0;
  signal decode_cnt   : integer range 0 to 64 := 0;
  signal output_cnt   : integer range 0 to 63 := 0;
  signal repeat_cnt   : integer range 0 to 255 := 0;
  signal current_val  : std_logic_vector(7 downto 0);
  signal current_count: integer range 0 to 255 := 0;
  signal state        : integer range 0 to 4 := 0;
  
begin
  
  process(clk, reset)
  begin
    if reset = '1' then
      input_cnt     <= 0;
      rle_idx       <= 0;
      decode_cnt    <= 0;
      output_cnt    <= 0;
      repeat_cnt    <= 0;
      state         <= 0;
      done          <= '0';
      data_out      <= (others => '0');
      current_val   <= (others => '0');
      current_count <= 0;
      
    elsif rising_edge(clk) then
      case state is
        
        when 0 =>  -- IDLE: Wait for start and read RLE buffer
          done <= '0';
          if start = '1' then
            rle_buffer(input_cnt) <= data_in;
            if input_cnt = (to_integer(reduced_length) - 1) then
              input_cnt  <= 0;
              rle_idx    <= 0;
              decode_cnt <= 0;
              repeat_cnt <= 0;
              state      <= 1;
            else
              input_cnt <= input_cnt + 1;
            end if;
          end if;
        
        when 1 =>  -- DECODE: Expand RLE entries into matrix using zigzag order
          if rle_idx < to_integer(reduced_length) and decode_cnt < 64 then
            -- Extract count and value from current RLE entry
            current_count <= to_integer(unsigned(rle_buffer(rle_idx)(15 downto 8)));
            current_val   <= rle_buffer(rle_idx)(7 downto 0);
            repeat_cnt    <= 0;
            state         <= 2;
          else
            -- All RLE entries processed or matrix full, move to output
            output_cnt <= 0;
            state      <= 3;
          end if;
        
        when 2 =>  -- EXPAND: Write current symbol 'count' times
          if decode_cnt < 64 and repeat_cnt < current_count then
            mem(zigzag_order(decode_cnt)) <= current_val;
            repeat_cnt  <= repeat_cnt + 1;
            decode_cnt  <= decode_cnt + 1;
          else
            -- Finished expanding current RLE entry or matrix full
            if decode_cnt >= 64 then
              -- Matrix is full, go to output
              output_cnt <= 0;
              state      <= 3;
            else
              rle_idx <= rle_idx + 1;
              state   <= 1;
            end if;
          end if;
        
        when 3 =>  -- OUTPUT: Send decoded matrix in row-major order
          done <= '1';
          data_out <= mem(output_cnt);
          if output_cnt = 63 then
            state <= 4;
          else
            output_cnt <= output_cnt + 1;
          end if;
        
        when 4 =>  -- DONE: Stay in done state
          done <= '1';
        
        when others =>
          null;
          
      end case;
    end if;
  end process;
  
end architecture;