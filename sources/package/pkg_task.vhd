-- ######################################################################################################################################################################################################
-- property of LATTICE
-- ######################################################################################################################################################################################################

-- ######################################################################################################################################################################################################
-- 01. libraries
-- ######################################################################################################################################################################################################
    -- ==================================================================================================================================================================================================
	-- 01.01. standard
    -- ==================================================================================================================================================================================================
    library ieee;
        use ieee.std_logic_1164.all;
        use ieee.numeric_std.all;
		use ieee.std_logic_unsigned.all;

    library std;
        use std.textio.all;

-- ######################################################################################################################################################################################################
-- 02. package header
-- ######################################################################################################################################################################################################

package pkg_task is
    
  constant INPUT_DLY:time:=10 ns;                    
  function slv8_xstr (inp: STD_LOGIC_VECTOR(7 downto 0)) return STRING;
  function slv4_xcha (inp: STD_LOGIC_VECTOR(3 downto 0)) return CHARACTER;   
  function slv1_xcha (inp: STD_LOGIC) return CHARACTER; 
                                                          
	procedure write(
	  constant address:in std_logic_vector(7 downto 0); 
	  signal addr:out std_logic_vector(1 downto 0);
	  signal rd_wr_l:out std_logic;
	  signal data_out:out std_logic_vector(7 downto 0);               
	  signal clk:in std_logic;
	  signal cs_l:out std_logic;
    signal ack_l:in std_logic
  );  
  
  procedure monitor_i2c_rdy(	 
	  signal addr:out std_logic_vector(1 downto 0);
	  signal rd_wr_l:out std_logic;              
	  signal clk:in std_logic;
	  signal cs_l:out std_logic;
    signal ack_l:in std_logic;
    signal data:in std_logic_vector(7 downto 0);
    signal num_errors:out integer
  );  
  
  
	  
	procedure read_data(
	  constant expected:in std_logic_vector(7 downto 0);                
	  signal addr:out std_logic_vector(1 downto 0);
	  signal rd_wr_l:out std_logic;
	  signal clk:in std_logic;
	  signal cs_l:out std_logic;
	  signal ack_l:in std_logic;
	  signal data:in std_logic_vector(7 downto 0);
	  signal num_errors:out integer
	  );  

end package pkg_task;

-- ######################################################################################################################################################################################################
-- 03. package body
-- ######################################################################################################################################################################################################

package body pkg_task is

function slv1_xcha (inp: STD_LOGIC) return CHARACTER is	  
variable result: character;

begin
	case inp is
    when '0' => result := '0';
    when '1' => result := '1';
    when 'H' => result := '1';
    when others => result := 'x';
  end case;
return result;
end;		
	
function slv4_xcha (inp: STD_LOGIC_VECTOR(3 downto 0)) return CHARACTER is
variable result: character;

begin
  case inp is
    when "0000" => result := '0';
    when "0001" => result := '1';
    when "0010" => result := '2';
    when "0011" => result := '3';
    when "0100" => result := '4';
    when "0101" => result := '5';
    when "0110" => result := '6';
    when "0111" => result := '7';
    when "1000" => result := '8';
    when "1001" => result := '9';
    when "1010" => result := 'a';
    when "1011" => result := 'b';
    when "1100" => result := 'c';
    when "1101" => result := 'd';
    when "1110" => result := 'e';
    when "1111" => result := 'f';
    when others => result := 'x';
  end case;
return result;
end;

-- converts slv byte to two char hex-string
function slv8_xstr (inp: STD_LOGIC_VECTOR(7 downto 0)) return STRING is
variable result : string (1 to 2);

begin
  result := slv4_xcha(inp(7 downto 4)) & slv4_xcha(inp(3 downto 0)); 
  return result;
end;	
	
  
procedure write(
	  constant address:in std_logic_vector(7 downto 0); 
	  signal addr:out std_logic_vector(1 downto 0);
	  signal rd_wr_l:out std_logic;
	  signal data_out:out std_logic_vector(7 downto 0);               
	  signal clk:in std_logic;
	  signal cs_l:out std_logic;
    signal ack_l:in std_logic
  ) is
	  	
	 begin
	 	 report "Writing Word Address";
	 	 addr<="00";
	 	 rd_wr_l  <='0' after INPUT_DLY;
	 	 data_out <=address  after INPUT_DLY;  --// 11/08 add input_dly for simulation purpose
	 	 wait until clk'event and clk='1';
	 	 cs_l<='0' after INPUT_DLY;
	 	 wait until ack_l='0';
	 	 wait until clk'event and clk='1';
	 	 cs_l<='1' after INPUT_DLY;
	 	 wait until clk'event and clk='1';
	 	 rd_wr_l  <='1' after INPUT_DLY;
   end;
   
   
   procedure monitor_i2c_rdy(	 
	  signal addr:out std_logic_vector(1 downto 0);
	  signal rd_wr_l:out std_logic;              
	  signal clk:in std_logic;
	  signal cs_l:out std_logic;
    signal ack_l:in std_logic;
    signal data:in std_logic_vector(7 downto 0);
    signal num_errors:out integer
  ) is
  	variable i2c_rdy:std_logic;
  	variable cntr_sun:std_logic_vector(7 downto 0);
  	variable num_errors_temp:integer;
  	begin
  	 num_errors_temp:=0;	
  	 i2c_rdy:='0';
  	 cntr_sun:="00000000";
  	 wait for 1 ns;
  	 while(i2c_rdy='0' and (cntr_sun /= "11111111")) loop
  	 	 wait for 10000 ns;
  	 	 addr<="10" after INPUT_DLY;
  	 	 wait until clk'event and clk='1';
  	 	 cs_l<='0' after INPUT_DLY;
  		 wait until ack_l='0';
  		 cntr_sun := cntr_sun + "00000001";
  		 wait for 10 ns;
  		 i2c_rdy := data(7);
  		 wait until clk'event and clk='1';
  		 cs_l<='1' after INPUT_DLY;
  	 end loop;
  	 
  	 if(i2c_rdy = '0') then
  	 	 report "<< ERROR: i2c never responded with data>>";
  		 num_errors_temp := num_errors_temp + 1;
  	 end if;
  	 num_errors<=num_errors_temp;
  	 report" leaving monitor ";
 
     i2c_rdy := '0';
    end;		

  procedure read_data(
	  constant expected:in std_logic_vector(7 downto 0);                
	  signal addr:out std_logic_vector(1 downto 0);
	  signal rd_wr_l:out std_logic;
	  signal clk:in std_logic;
	  signal cs_l:out std_logic;
	  signal ack_l:in std_logic;
	  signal data:in std_logic_vector(7 downto 0);
	  signal num_errors:out integer
	  ) is
    variable data_ret:std_logic_vector(7 downto 0);  
    variable num_errors_temp:integer;
    begin
    	num_errors_temp:=0;	
    	wait for 1000 ns;
    	report" Reading Data ";
    	addr<="01" after INPUT_DLY;
    	wait until clk'event and clk='1';
    	wait for 1 ns;--// 12/10/08 add additon delay to off set a timing issue with VHDL simulation
    	cs_l<='0' after INPUT_DLY;
    	wait until ack_l='0';
    	wait until clk'event and clk='1';
    	if(ack_l='0') then
    		 report": Data =" & slv8_xstr(data);--,data);
    		 data_ret:=data;
      end if;
    	cs_l<='1' after INPUT_DLY;
    	rd_wr_l  <='1' after INPUT_DLY;
    	
    	if (data_ret /= expected) then
        report "<< ERROR: data returned = " &  slv8_xstr(data_ret) & " ,data_expected = " & slv8_xstr(expected) ;--, data_ret, expected);
        num_errors_temp := num_errors_temp + 1; 
      end if;
      num_errors<=num_errors_temp;
    	
   end;
	
end package body pkg_task;

-- ######################################################################################################################################################################################################
-- EOF
-- ######################################################################################################################################################################################################