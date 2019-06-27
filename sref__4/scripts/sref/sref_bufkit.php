<?php

// Author: 	Chris Karstens
// Date: 	February 21, 2012
// Versions:	PHP, Perl, Bufrgruven
// Purpose:	1) Generate SREF bufkit profiles
//		2) Insert data into ldm archives
// Notes:	1) To run this script on the fly, issue the following command (specify date as model run time + 4 hours in UTC):
//		php sref_bufkit.php now="2012-02-10 16:00:00" 

putenv("TZ=UTC");

if(isset($argv)){
	for($c=1;$c<count($argv);$c++){
        	$it = split("=",$argv[$c]);
        	$_GET[$it[0]] = $it[1];
     	}
}

$now1 = date("Y-m-d H:00:00");
$now = isset($_GET["now"]) ? $_GET["now"] : $now1;
$t = strtotime($now);
$st = $t - (4*3600);
$stime = date("Ymd",$st);
$shour = date("H",$st);
$iem_date = date("YmdHi",$st);
$model = "sref";
$model2 = "sref4";
$cur_dir = "/local/ckarsten/bufkit/".$model2."/scripts/".$model."/";
$data_dir = "/local/ckarsten/bufkit/sref1/scripts/".$model."/data/";


// generate list of files available from the bufr download
$files = scandir($data_dir);
$n1 = 1030;
$n = 1375;
$j = 0;
$sites = array();
$numbers = array();
$link = "/local/ckarsten/bufkit/sref1/stations/".$model."_bufrstations.txt";
$data = file($link);
foreach($data as $line){
	$d = explode(" ", trim(ereg_replace( ' +', ' ', $line)));
	$numbers[] = $d[0];
	$sites[] = $d[3];
}


// generate bufkit data
// insert into ldm archives
for($i=$n1;$i<=$n;$i++){
	$j++;
	$s = explode(".",$files[$i]);
	$site = $s[1];
	$index = array_search($site,$numbers);
	echo "Processing: ".$site.", ".strtolower($sites[$index])."\n";
	system("perl /local/ckarsten/bufkit/".$model2."/bufr_gruven.pl --nfs --dset ".$model." --date ".$stime." --cycle ".$shour." --noascii --stations ".$site."");
	$filename = "/local/ckarsten/bufkit/".$model2."/metdat/bufkit/".$model."_".strtolower($sites[$index]).".buz";
	if(file_exists($filename)){
		$cmd = "/local/ldm/bin/pqinsert -p 'bufkit ac ".$iem_date." bufkit/".$model."/".$model."_".strtolower($sites[$index]).".buz bufkit/".$shour."/".$model."/".$model."_".strtolower($sites[$index]).".buz bogus' ".$filename."";
		echo "".$cmd."\n";
		system($cmd);
        }
	
	// the following block of code is needed, otherwise data processing will terminate after about 60 or 70 files are processed.
	// I believe there is memory leakage occuring.
	if($j == 50){
                system("mv /local/ckarsten/bufkit/".$model2."/metdat/bufkit/*.buz /local/ckarsten/bufkit/".$model2."/metdat/bufkit_temp/");
		system("rm /local/ckarsten/bufkit/".$model2."/metdat/ascii/*");
		system("rm /local/ckarsten/bufkit/".$model2."/metdat/bufr/*");
		system("rm /local/ckarsten/bufkit/".$model2."/metdat/gempak/*");
                $j = 0;
        }        

}

// final clean-up
system("mv /local/ckarsten/bufkit/".$model2."/metdat/bufkit/*.buz /local/ckarsten/bufkit/".$model2."/metdat/bufkit_temp");
system("rm /local/ckarsten/bufkit/".$model2."/metdat/ascii/*");
system("rm /local/ckarsten/bufkit/".$model2."/metdat/bufr/*");
system("rm /local/ckarsten/bufkit/".$model2."/metdat/gempak/*");
system("rm /local/ckarsten/bufkit/".$model2."/scripts/".$model."/data/*");

// generate cobb data
// note: make_cobb.php inserts data into ldm
//system("php /local/ckarsten/bufkit/".$model2."/cobb/make_cobb.php iem_date=".$iem_date." hour=".$shour." model=".$model2."");

system("rm /local/ckarsten/bufkit/".$model2."/metdat/bufkit_temp/*.buz");
system("rm /local/ckarsten/bufkit/".$model2."/cobb/data/*.dat");

?>
