--   ==================================================================
--   >>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<
--   ------------------------------------------------------------------
--   Copyright (c) 2013 by Lattice Semiconductor Corporation
--   ALL RIGHTS RESERVED 
--   ------------------------------------------------------------------
--
--   Permission:
--
--      Lattice SG Pte. Ltd. grants permission to use this code
--      pursuant to the terms of the Lattice Reference Design License Agreement. 
--
--
--   Disclaimer:
--
--      This VHDL or Verilog source code is intended as a design reference
--      which illustrates how these types of functions can be implemented.
--      It is the user's responsibility to verify their design for
--      consistency and functionality through the use of formal
--      verification methods.  Lattice provides no warranty
--      regarding the use or functionality of this code.
--
--   --------------------------------------------------------------------
--
--                  Lattice SG Pte. Ltd.
--                  101 Thomson Road, United Square #07-02 
--                  Singapore 307591
--
--
--                  TEL: 1-800-Lattice (USA and Canada)
--                       +65-6631-2000 (Singapore)
--                       +1-503-268-8001 (other locations)
--
--                  web: http:--www.latticesemi.com/
--                  email: techsupport@latticesemi.com
--
--   --------------------------------------------------------------------
--  Name:  model_eeprom_iic
--
--  Description: I2C slave simulation model for I2C serial controller
---------------------------------------------------------------------------
-- Code Revision History :
---------------------------------------------------------------------------
-- Ver: | Author			|Mod. Date	|Changes Made:
-- V1.0 | 				|2004           |Initial ver
-- V1.1 | C.M.	                	|11/2008        |update header, modified
--                                                      |sda_out for ack state
-- converted from i2c serial eprom ref design RD1006
---------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;       
use work.pkg_task.all;

entity model_eeprom_iic is
	port (
	 scl:in std_logic;
	 sda:inout std_logic
	  );
  end entity;

  architecture arch of model_eeprom_iic is
  type mem_type is array (255 downto 0) of std_logic_vector(7 downto 0);
  signal clk, rst_l:std_logic;
  signal mem:mem_type;-- // 2^8 = 256 locations
  signal word_address:std_logic_vector(7 downto 0):="00000000";-- // counts the active byte
  signal start_detect:std_logic;
  signal stop_detect:std_logic;
  signal sda_reg, sda_reg_delayed:std_logic;
  signal scl_reg, scl_reg_delayed:std_logic;
  signal start_pulse, stop_pulse, scl_pulse, scl_neg_pulse:std_logic;
  signal address_reg_7:std_logic_vector(6 downto 0); -- // All 7 Bits of 7 bit addressing
  signal temp10:std_logic_vector(9 downto 0);
  signal address_reg_10_upper:std_logic_vector(6 downto 0);-- // Upper 2 bits of address
  signal address_reg_10_lower:std_logic_vector(7 downto 0); --// lower 8 bits of address
  signal current_state:std_logic_vector(3 downto 0);
  signal next_state:std_logic_vector(3 downto 0):="0000";
  signal in_reg:std_logic_vector(7 downto 0);
  signal out_reg:std_logic_vector(7 downto 0):="00000000"; --// registers used to hold the input
                       --// and output data to-from the sda line
  signal bit_counter:std_logic_vector(3 downto 0):="0000"; --// Used to counter what bit is being selected
                         --// for the in_reg and out_reg
  signal r_w_bit:std_logic:='0'; --// used to hold the read write bit;
  signal hit_7:std_logic:='0';
  signal hit_10_upper:std_logic:='0';
  signal hit_10_lower:std_logic:='0';-- // flags for address hits
  signal sda_out:std_logic:='0';
  signal in_reg_enable:std_logic:='0'; --// the clock enable for the in_reg registers.
  signal out_en:std_logic:='0'; --// the output enable
  signal word_add_flag:std_logic:='0';
  signal ack_flag:std_logic:='0';
  signal temp_add_upper:std_logic_vector(7 downto 1):="0000000";
  signal temp_add_lower:std_logic_vector(7 downto 0):="00000000"; --// temp_add_upper & temp_add_lower are
                      -- // used to hold the first &
                      -- // second address bytes of 10 bit
                      --// addressing so that during a 10 bit addressing
                      --// read the value of the current 10 bit address
                      --// can be compared with the last read.
  signal read_10_flag:std_logic:='0'; --// This flag is set when the temp_add matches the current
                    --// address_reg_10_upper and the r/w is a 1.  This tells
                    --// the ack to goto a data read state instead of getting
                    --// the second byte of address.

  --//-------------------------------------------------------------------
  --// misc variables
  signal i:integer range 0 to 255 ;
  --//-------------------------------------------------------------------


  --// used for address_mode parameter
  constant seven_bit:integer:=0 ;
  --  // used for address_mode parameter
  constant ten_bit:integer:=1;
  --  // used in upper 5 bits of address_reg_10_upper
  --  // DON'T CHANGE
  constant ten_bit_add:std_logic_vector(4 downto 0):="11110";
  -- // a 1 turns this on and a 0 off
  constant debug:std_logic:= '0';

  --//-------------------------------------------------------------------

  constant period:time:=30 ns; -- // using 33 MHz
  constant reset_time:time:=20 ns;-- // hold reset low this long

  --// DESIGNER SET the following parameter to use 7 or 10 bit addressing
  constant address_mode:integer:=seven_bit; --// Use `seven_bit or `ten_bit

  --// depending on the value in address_mode either seven_bit_address or
  --// ten_bit_address will be used.
  --
  --// DESIGNER SET the next parameter with the 7 bit address the slave
  --// should respond to. MSB->LSB
  --// example: 7'b1010_000;
  constant seven_bit_address:std_logic_vector(6 downto 0):="1010000";

  --// DESIGNER SET the next parameter with the 10 bit address the slave
  --// should respond to. MSB->LSB
  --// example: 10'b10_1100_1010;
  constant ten_bit_address:std_logic_vector(9 downto 0):= "1011001010";

  --// state bits
  constant idle:std_logic_vector(3 downto 0):="0000";
  constant start:std_logic_vector(3 downto 0):="0001";
  constant address:std_logic_vector(3 downto 0):="0010";
  constant ack:std_logic_vector(3 downto 0):="0011";
  constant data:std_logic_vector(3 downto 0):="0100";
  constant data_ack:std_logic_vector(3 downto 0):="0101";

  constant tdh:time:= 100 ns; --// tdh = data out hold time min

  signal bool:std_logic:='1';

  begin
  	--// internal clock for the model
  	 clk_gen:process
	   begin
	   	 clk<='0';
	   	 wait for period/2;
	   	 loop
	   	 	 clk<=not clk;
	   	 	 wait for period/2;
	   	 end loop;
	  end process;

  --// print some status
   process(scl)
    begin
    	if(scl'event and scl='H') then
    		if(debug='1') then
    		 report "Received Clock Data" ;--,sda
    		end if;
  	  end if;
   end process;

  --// initialize the address registers, mem array, clk and control the reset
  initial:process
    
    begin
    	--// initialize the address registers
    if (address_mode = seven_bit) then
      report"Using 7 Bit Addressing" ;
      address_reg_7<= seven_bit_address;

    elsif (address_mode =ten_bit) then
      report"Using 10 Bit Addressing";
      temp10<= ten_bit_address;
      address_reg_10_upper<= (ten_bit_add & temp10(9 downto 8)); --// 2 MSB
      address_reg_10_lower<= temp10(7 downto 0);

    else
      report "ERROR: address_mode parameter is INVALID!! ";
    end if;    
--    r_w_bit<='0';
--    out_reg<="00000000";
--    out_en<='0'; --// disable output
--    bit_counter<='0';
--    word_address<="00000000";-- // initialize byte #
--    word_add_flag<='0';
--    ack_flag<='0';
--    in_reg_enable<='0';
--    temp_add_upper<='0';
--    temp_add_lower<='0';
--    read_10_flag = 0;
--    hit_10_upper = 0;
--    hit_10_lower = 0;
--    hit_7 = 0;
--    clk = 1'b0;  // initalize clock
--    next_state = 5'b0;
    rst_l<='0'; -- // turn on reset signal
    wait for reset_time;
    rst_l<='1'; --// turn off reset signal
    wait;
  end process;

  --//-------------------------------------------------------------------------
  --// sda_out is an internal reg that is assigned a 0 when the output should be
  --// 0 and it assigns a Z otherwise.
   sda<='0' when (sda_out='0' and out_en='1') else 'Z';
  -- //--------------------------------------------------------------------
   --// start and stop detect logic
  	 process(clk,rst_l)
		 begin
		 	 if(rst_l='0') then
		 	 	 sda_reg <='H'; --// bus is active low
         sda_reg_delayed <='H';
		 	 elsif(clk' event and clk='1') then
		 	 	 sda_reg <= sda;
         sda_reg_delayed <= sda_reg;
		 	 end if;
		 end process;

	 --	 // detect a high to low while scl is high
   --// start_pulse
    process(clk,rst_l)
		 begin
		 	 if(rst_l='0') then
		 	 	 start_pulse<='0';
		 	 elsif(clk' event and clk='1') then
		 	 	 if(sda_reg='0' and sda_reg_delayed='H' and scl='H') then
		 	 	   start_pulse<='1';
		 	 	 else
		 	 	   start_pulse<='0';
		 	 	 end if;
		 	 end if;
		 end process;

		 --// start flag
  	 process(clk,rst_l)
		 begin
		 	 if(rst_l='0') then
		 	 	 start_detect<='0';
		 	 elsif(clk' event and clk='1') then
		 	 	 if(start_pulse='1') then
		 	 	   start_detect <= '1';
		 	 	 elsif(scl='0') then
		 	 	   start_detect <='0';-- // clear start bit
		 	 	 else
		 	 	   start_detect <= start_detect;
		 	 	 end if;
		 	 end if;
		 end process;

		-- // detect a low to high while scl is high
    --// stop_pulse
  	 process(clk,rst_l)
		 begin
		 	 if(rst_l='0') then
		 	 	 stop_pulse<='0';
		 	 elsif (clk'event and clk='1') then
		 	 	 if (sda_reg='H' and sda_reg_delayed='0' and scl='H') then
		 	 	   stop_pulse<='1';
		 	 	 else
		 	 	   stop_pulse<='0';
		 	 	 end if;
		 	 end if;
		 end process;

		 --//stop flag
		 process(clk,rst_l)
		 begin
		 	 if(rst_l='0') then
		 	 	 stop_detect<='0';
		 	 elsif(clk' event and clk='1') then
		 	 	 if(stop_pulse='1') then
		 	 	   stop_detect <= '1';
		 	 	 elsif(current_state = idle) then
		 	 	   stop_detect <='0';-- // clear start bit

		 	 	 end if;
		 	 end if;
		 end process;


		-- //--------------------------------------
    --// SCL posedge & nededge detector regs
    process(clk,rst_l)
		 begin
		 	 if(rst_l='0') then
		 	 	  scl_reg <='H';
          scl_reg_delayed <='H';
		 	 elsif(clk' event and clk='1') then
		 	 	  scl_reg <= scl;
          scl_reg_delayed <= scl_reg;
		 	 end if;
		 end process;

		 --// SCL posedge detector
     process(clk,rst_l)
		 begin
		 	 if(rst_l='0') then
		 	 	 scl_pulse<='0';
		 	 elsif(clk' event and clk='1') then
		 	 	 if(scl_reg='H' and scl_reg_delayed='0') then
		 	 	   scl_pulse <='1';
		 	 	 else
		 	 	   scl_pulse <='0';

		 	 	 end if;
		 	 end if;
		 end process;

		 --// SCL negedge detector
     process(clk,rst_l)
		 begin		 	
		 	 if(rst_l='0') then
		 	 	 scl_neg_pulse<='0';
		 	 elsif(clk' event and clk='1') then
		 	 	 if(scl_reg='0' and scl_reg_delayed='H') then
		 	 	   scl_neg_pulse <='1';
		 	 	 else
		 	 	   scl_neg_pulse <='0';   

		 	 	 end if;
		 	 end if;
		 	end process; 
		 	 --// Output Mux
		 	 --process(bit_counter,out_reg)
		 	 -- begin
		 	 -- 	case (bit_counter) is
		 	 -- 		when "0000" => sda_out<=out_reg(7);
       --     when "0001" => sda_out<=out_reg(6);
       --     when "0010" => sda_out<=out_reg(5);
       --     when "0011" => sda_out<=out_reg(4);
       --     when "0100" => sda_out<=out_reg(3);
       --     when "0101" => sda_out<=out_reg(2);
       --     when "0110" => sda_out<=out_reg(1);
       --     when "0111" => sda_out<=out_reg(0);
       --     when "1000" => sda_out<='0';  --// 11/08 add this condition to ensure sda=0 at ack state for 7-bit i2c simulation
       --     when others => sda_out<= out_reg(0);
       --   end case;
       --end process;

--       // Input De-Mux
     process(clk,rst_l)
		 begin
		 	 if(rst_l='0') then
		 	 	 in_reg<="00000000";
		 	 elsif(clk' event and clk='1') then
		 	 	 if(in_reg_enable='1') then
		 	 	 	 case bit_counter is
		 	  		when "0000" =>
		 	  		  if(sda_reg_delayed='H' or sda_reg_delayed='1') then
		 	  		  	 in_reg(7)<='1';
		 	  		  else
		 	  		     in_reg(7)<=sda_reg_delayed;
		 	  		  end if;
            when "0001" =>
              if(sda_reg_delayed='H' or sda_reg_delayed='1') then
                in_reg(6)<='1';
              else
		 	  		     in_reg(6)<=sda_reg_delayed;
		 	  		  end if;
            when "0010" =>
              if(sda_reg_delayed='H' or sda_reg_delayed='1') then
                in_reg(5)<='1';
              else
                in_reg(5)<=sda_reg_delayed;
              end if;
            when "0011" =>
              if(sda_reg_delayed='H' or sda_reg_delayed='1') then
                 in_reg(4)<='1';
              else
                 in_reg(4)<=sda_reg_delayed;
              end if;
            when "0100" =>
              if(sda_reg_delayed='H' or sda_reg_delayed='1') then
                 in_reg(3)<='1';
              else
                 in_reg(3)<=sda_reg_delayed;
              end if;
            when "0101" =>
              if(sda_reg_delayed='H' or sda_reg_delayed='1') then
                 in_reg(2)<='1';
              else
                 in_reg(2)<=sda_reg_delayed;
              end if;
            when "0110" =>
              if(sda_reg_delayed='H' or sda_reg_delayed='1') then
                 in_reg(1)<='1';
              else
                 in_reg(1)<=sda_reg_delayed;
              end if;
            when "0111" =>
              if(sda_reg_delayed='H' or sda_reg_delayed='1') then
                 in_reg(0)<='1';
              else
                 in_reg(0)<=sda_reg_delayed;
              end if;

            when others => in_reg<="00000000";
          end case;
        else
          in_reg<=in_reg;
        end if;
      end if;
   end process;

     --// I2C Slave State Machine
     process(clk,rst_l)
     variable mem_temp:std_logic_vector(7 downto 0):="00000000";
		 begin
		 	    --// initialize the mem array
		 	 if (bool='1') then
         for i in 0 to 255 loop
           mem(i)<= mem_temp;
           mem_temp:=mem_temp+"00000001";
         end loop;
    	   bool<='0';
       end if; 
       
       
       case (bit_counter) is
		 	  		when "0000" => sda_out<=out_reg(7);
            when "0001" => sda_out<=out_reg(6);
            when "0010" => sda_out<=out_reg(5);
            when "0011" => sda_out<=out_reg(4);
            when "0100" => sda_out<=out_reg(3);
            when "0101" => sda_out<=out_reg(2);
            when "0110" => sda_out<=out_reg(1);
            when "0111" => sda_out<=out_reg(0);
            when "1000" => sda_out<='0';  --// 11/08 add this condition to ensure sda=0 at ack state for 7-bit i2c simulation
            when others => sda_out<= out_reg(0);
          end case;
       
		 	 if(rst_l='0') then
		 	 	 current_state<=idle after 1 ns;
		 	 elsif(clk' event and clk='1') then
		 	 	case current_state is
          when idle =>
                  if (start_detect='1' and scl='H') then
                    current_state <=start after 1 ns;
                  else
                    current_state <=idle after 1 ns;
                    in_reg_enable <='0' after 1 ns;
                  end if;
          when start =>
                  if (start_detect='1' and scl='H') then
                    current_state <= start after 1 ns;
                  end if;

                  if (stop_detect='1' and scl='H') then
                    current_state <=idle after 1 ns;
                  elsif (scl_pulse='1') then
                      bit_counter <= "0000" after 1 ns;
                      in_reg_enable <='1' after 1 ns;
                  elsif (in_reg_enable='1' ) then
                      in_reg_enable <= '0';
                      bit_counter <= bit_counter + "0001" after 1 ns;
                      current_state<=address after 1 ns;
                      --// clear all the address hit flags
                      hit_7 <= '0' after 1 ns;
                      hit_10_upper <= '0' after 1 ns;
                      hit_10_lower <= '0' after 1 ns;
                      word_add_flag <= '0' after 1 ns;
                      ack_flag <= '0' after 1 ns;
                  end if;

          when address =>
                    if (start_detect='1' and scl='H') then
                      current_state <=start after 1 ns;
                    elsif (stop_detect='1' and scl='H') then
                      current_state <=idle after 1 ns;
                    elsif (scl_pulse='1' and (bit_counter <="1000")) then
                      in_reg_enable <= '1' after 1 ns;
                    elsif (in_reg_enable='1') then
                      in_reg_enable <= '0' after 1 ns;
                      bit_counter <=bit_counter + "0001" after 1 ns;
                      current_state <=address after 1 ns;
                    elsif (bit_counter="1000" and address_mode = seven_bit) then
                         --// determine if r or w and set r_w_bit
                         if (in_reg(7 downto 1) = address_reg_7) then
                           r_w_bit <=in_reg(0) after 1 ns;
                           current_state <=ack after 1 ns;
                           hit_7 <='1' after 1 ns;
                           ack_flag <='0' after 1 ns; --// used in ack state
                         else
                           --// the address is not for this slave
                           sda_out <= '1' after 1 ns;
                           current_state <=idle after 1 ns;
                         end if;
                --// check if upper address byte is a hit in 10 bit addressing
                    elsif (bit_counter = "1000" and address_mode=ten_bit and hit_10_upper ='0') then
                      --// first time checking upper hit
                         if (in_reg(7 downto 1) = address_reg_10_upper) then
                               r_w_bit <=in_reg(0) after 1 ns;
                               current_state <=ack after 1 ns;
                               hit_10_upper <= '1' after 1 ns;
                               ack_flag <= '0' after 1 ns; --// used in ack state
                               if (in_reg(0) = '0') then
                                 temp_add_upper <= in_reg(7 downto 1) after 1 ns;
                                 read_10_flag <= '0' after 1 ns;-- // clear
                               elsif ((in_reg(0) = '1') and (temp_add_upper = in_reg(7 downto 1)) and (temp_add_lower = address_reg_10_lower) ) then
                                 --// This flag is set because the last 10 bit addressing
                                 --// mode write was for this slave, so this read only
                                 --// requires a match of the first byte of addressing
                                 read_10_flag <='1' after 1 ns; --// set
                               end if;
                         else
                              --// the address is not for this slave
                              sda_out <= '1' after 1 ns;
                              current_state <=idle after 1 ns;
                              temp_add_upper<= in_reg(7 downto 1); --// holds value of last
                                                                 --// upper add
                              read_10_flag <='0' after 1 ns; --// clear
                         end if;
              --// check if lower address byte is a hit in 10 bit addressing
                    elsif (bit_counter = "1000" and address_mode=ten_bit and hit_10_upper ='1') then
                         --// is the lower address a hit?
                         if (in_reg(7 downto 0) = address_reg_10_lower) then
                           current_state <= ack after 1 ns;
                           hit_10_lower <='1' after 1 ns;
                           ack_flag <= '0' after 1 ns; --// used in ack state
                           temp_add_lower <= in_reg(7 downto 0) after 1 ns;
                         else
                           --// the address is not for this slave
                           sda_out <='1' after 1 ns;
                           current_state <=idle after 1 ns;
                           temp_add_lower <=in_reg(7 downto 0) after 1 ns;
                         end if;

                    end if;
          when ack =>
            --// starts with scl high
            --// if we get a start goto start
                  if (start_detect='1' and scl='H') then
                      current_state <=start after 1 ns;
            --// if there is a stop goto idle
                  elsif (stop_detect='1' and scl='H') then
                      current_state <= idle after 1 ns;
            --// if there is an address hit acknowledge the address
                  elsif ((hit_7='1' or hit_10_upper='1' or hit_10_lower='1') and scl_neg_pulse='1' and ack_flag='0') then
                     out_en <='1' after tdh; --// turn on OE
                     ack_flag <='1' after 1 ns;
            --// once the acknowledge is presented turn off the OE
            --// print the address, and goto address or data depending on
            --// addressing mode
                  elsif ((hit_7='1' or hit_10_upper='1' or hit_10_lower='1') and scl_neg_pulse='1' and ack_flag='1' ) then
                     out_en <='0' after tdh;-- // #1 0; // turn off OE
                     bit_counter <="0000" after 1 ns;
                     if (hit_10_upper='1' and hit_10_lower='0') then
                         report"<< 10 bit addressing Upper address is " & slv8_xstr(in_reg) &">>";--, in_reg);
                         if (read_10_flag = '0') then
                           current_state <=address after 1 ns;
                         elsif (read_10_flag = '1') then
                           --// going to the data state because a read in 10 bit
                           --// addressing only requires a hit on the upper address if
                           --// the last write was a hit.
                           current_state <=data after 1 ns;
                         end if;
                     elsif (hit_7='1' or hit_10_lower='1') then
                         --// hit_10_lower or hit_7
                         current_state <=data after 1 ns;
                         if (hit_10_lower='1') then
                          report "<< 10 bit addressing Lower address is "& slv8_xstr(in_reg) &">>";--, in_reg);
                         elsif (hit_7='1') then
                          report"<< 7 bit addressing & address is "& slv8_xstr(in_reg) &">>";--, in_reg);
                         end if;
                     end if;

                  --//((hit_7 || hit_10_upper || hit_10_lower) && scl_neg_pulse  && ack_flag ) begin
                  --// if there is no hit, return to idle
                  elsif (hit_7='0' and hit_10_upper='0' and hit_10_lower='0') then
                     --// no_ack
                     out_en<='0' after 1 ns;
                     bit_counter <="0000" after 1 ns;
                     current_state <=idle after 1 ns;
                  end if;
          when data =>
                  --// starts with scl low
                  if (start_detect='1' and scl='H') then
                      current_state <=start after 1 ns;
                  elsif (stop_detect='1' and scl='H') then
                    current_state <=idle after 1 ns;
                   --// write data
                  else -- // outer else
                        if (r_w_bit='0' and scl_pulse='1' and (bit_counter <="1000") ) then
                           --// write
                          in_reg_enable <='1' after 1 ns;
                        elsif (r_w_bit='0' and in_reg_enable='1' and (bit_counter <="1000")) then
                          --// write more
                          in_reg_enable <='0' after 1 ns;
                          bit_counter <=bit_counter + "0001" after 1 ns;
                          current_state <= data after 1 ns;
                        elsif (r_w_bit='0' and (bit_counter ="1000")) then
                           --// write last bit
                           in_reg_enable <='0' after 1 ns; --// disable
                           current_state <=data_ack after 1 ns;
                           ack_flag <='0' after 1 ns; --// used in data_ack state
                           if (word_add_flag='0') then
                             word_address <=in_reg after 1 ns;
                             word_add_flag <= '1' after 1 ns; --// set the flag
                           else
                             mem(conv_integer(word_address)) <=in_reg after 1 ns;
                             word_address <=word_address +"00000001"  after 1 ns;
                           end if;

                        -- // read data
                        elsif (r_w_bit='1' and (bit_counter ="0000") and scl_neg_pulse='0') then
                           --// read first bit of word
                           --// scl is low at start of read
                           out_en <='1'  after tdh; --// turn on OE
                           out_reg <=mem(conv_integer(word_address)) after tdh;
                        elsif (r_w_bit='1' and (bit_counter < "0111") and scl_neg_pulse='1') then
                            --// set up next bit
                            bit_counter <=bit_counter + "0001" after tdh;
                        elsif (r_w_bit='1' and (bit_counter = "0111") and scl_neg_pulse='1') then
                          --// we already output the last bit
                          bit_counter <= "0000"  after tdh;
                          out_en <= '0' after tdh; --// turn off OE
                          word_address <= word_address + "00000001" after 1 ns;
                          current_state <=data_ack after 1 ns;
                          ack_flag <= '0' after 1 ns; --// used in data_ack state
                         end if;
                  end if;-- // outer else
          when data_ack =>
                  if (start_detect='1' and scl='H') then
                      current_state <=start after 1 ns;
                  elsif (stop_detect='1' and scl='H') then
                      current_state <=idle after 1 ns;
               --// starts with scl high on write
                  elsif (r_w_bit='0' and scl_neg_pulse='1' and ack_flag='0') then
                     report "<< Slave Data Received on write is "& slv8_xstr(in_reg) &">>";--, in_reg);
                     out_en <= '1' after 10 ns; --// turn on OE
                     sda_out <='0' after 20 ns;--  // sda is 0 so ack
                     ack_flag <= '1' after 1 ns;
                  elsif (r_w_bit='0' and scl_neg_pulse='1' and ack_flag='1' ) then
                     out_en <='0' after 10 ns; --// turn off OE
                     sda_out <= '1' after 20 ns; --// sda is becomes a Z
                     bit_counter <="0000" after 1 ns;
                     current_state <=data after 1 ns;
                --// starts with scl low on read
                  elsif (r_w_bit='1' and scl_pulse='1') then
                     --// check sda for ack now
                     report " << Slave Data transmitted on read is "& slv8_xstr(out_reg) &">>";--, out_reg);
                     if (sda='0') then
                       next_state <=data after 1 ns;
                       bit_counter <= "0000" after 1 ns;
                       report " Master ACK'd on a Data Read, returning to Data ";
                       ack_flag <='1' after 1 ns;

                     elsif (sda='H') then
                       report"No ACK on a Data Read, returning to Idle ";
                       next_state <=idle after 1 ns;
                       ack_flag <= '1' after 1 ns;
                     end if;

                  elsif (r_w_bit='1' and scl_neg_pulse='1') then
                    current_state <=next_state after 1 ns;
                  end if;
          when others =>
                    if (start_detect='1' and scl='H') then
                      current_state <=start after 1 ns;
                    elsif (stop_detect='1' and scl='H') then
                      current_state <=idle after 1 ns;
                    else
                      current_state <=idle after 1 ns;
                      report"Something is broken is the SM returning to idle";
                    end if;

          end case;

    end if; --// end of if

  end process;--// end of process

  end arch;
  
  
