<?php

$data_dir = "/local/ckarsten/bufkit/nam/metdat/bufkit_temp";
$files = scandir($data_dir);
$n = count($files) - 1;
$master_list = "nam_bufrstations_new.txt";
$data = file($master_list);
$sites = array();

foreach($data as $line){
	$d = explode(" ", trim(ereg_replace( ' +', ' ', $line)));
	if($d[1] == "00.00"){
		$link = "".$data_dir."/namm_".$d[0].".buf";
		$data2 = file($link);
		$i = 0;
		foreach($data2 as $line2){
			$i++;
			if($i == 6){
				$d2 = explode(" ",$line2);
				$lat = $d2[2];
				$lon = $d2[5];
				if($lat < 0){
					$sym1 = "S";
				}
				else{
					$sym1 = "N";
				}
				if($lon < 0){
					$sym2 = "W";
				}
				else{
					$sym2 = "E";
				}
				/*
				$link3 = "http://mesonet.agron.iastate.edu/request/asos/csv.php?lat=".$lat."&lon=".$lon."";
				$data3 = file($link3);
				$j = 0;
				foreach($data3 as $line3){
					$j++;
					if($j == 2){
						$d3 = explode(",",$line3);
						$site = $d3[0];
						break;
					}	
				}
				*/
				$site = $d[3];
				echo "".$d[0]." ".$lat." ".$lon." ".$site."\n";
			}	
		}
	}	
	else{
		echo $line;
	}
}

?>
