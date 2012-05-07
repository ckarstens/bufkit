<?php

$data_dir = "/local/ckarsten/bufkit/nam/scripts/nam/data/";
$files = scandir($data_dir);
$n = count($files) - 1;
$master_list = "nam_bufrstations.txt";

for($i=2;$i<=$n;$i++){
	$found = 0;
        $d = explode(".",$files[$i]);
        $site = @$d[1];
	$data = file($master_list);
	foreach($data as $line){
        	$d = explode(" ", trim(ereg_replace( ' +', ' ', $line)));
	        $cur_site = $d[0];
	        if($cur_site == $site){
	                echo $line;
			$found = 1;
			break;
	        }
	}
	if($found == 0){
		echo "".$site." 00.00  00.00  ".$site."\n";
	}
}


?>
