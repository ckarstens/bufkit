<?php

if(isset($argv)){
	for($i=1;$i<count($argv);$i++){
        	$it = split("=",$argv[$i]);
          	$_GET[$it[0]] = $it[1];
     	}
}


$model = isset($_GET["model"]) ? $_GET["model"] : "gfs3";
$iem_date = isset($_GET["iem_date"]) ? $_GET["iem_date"] : "2010021012";
$hour = isset($_GET["hour"]) ? $_GET["hour"] : "12";
if($model == "gfs3"){
	$model2 = "gfs";
}
else{
	$model2 = $model;
}
if($hour == "06" || $hour == "18"){
	if($model == "gfs3"){
		$model1 = "gfsm";
	}
	elseif($model == "nam"){
		$model1 = "namm"; 
	}
}
else{
        if($model == "gfs3"){
                $model1 = "gfs";
        }
        elseif($model == "nam"){
                $model1 = "nam";
        }
}
$dir = "/local/ckarsten/bufkit/".$model2."/cobb";
$out_dir = "/local/ckarsten/bufkit/".$model2."/cobb/data";
$data_dir = "/local/ckarsten/bufkit/".$model2."/metdat/bufkit_temp/";

system("rm ".$data_dir."20*");
$files = scandir($data_dir);
$n = count($files) - 1;

for($i=2;$i<=$n;$i++){
	$s = explode(".",$files[$i]);
	$s2 = explode("_",$s[0]);
	$site = $s2[1];
	echo "".$site."\n";
	$filename = "".$out_dir."/".$model."_".$site.".dat";
	system("perl ".$dir."/cobb.pl ".$site." ".$model." > ".$filename."");
	if(file_exists($filename) && filesize($filename) > 1){
        	system("/local/ldm/bin/pqinsert -p 'bufkit c ".$iem_date." cobb/".$hour."/".$model2."/".$model."_".$site.".dat cobb/".$hour."/".$model2."/".$model."_".$site.".dat bogus' ".$filename."");
        }

}

?>
