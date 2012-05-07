<?php

$link = "gfs3_bufrstations_new.txt";
$sites = array();
$data = file($link);

foreach($data as $line){
	$d = explode(" ", trim(ereg_replace( ' +', ' ', $line)));
	$sites[] = $d[3];	
}

$n = count($sites) - 1;

for($i=0;$i<=$n;$i++){
	$site = $sites[$i];
	for($j=$i+1;$j<=$n;$j++){
		if($site == $sites[$j]){
			echo "".$site."\n";
		}
	}
}

?>
