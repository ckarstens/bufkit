<?php
// Author: 	Chris Karstens
// Date: 	February 16, 2012
// Versions:	PHP, Perl, Bufrgruven
// Purpose:	1) Generate GFS bufkit profiles
//		2) Insert data into ldm archives
// Notes:	1) To run this script on the fly, issue the following command
// (specify date as model run time + 4 hours in UTC):
//		php gfs_bufkit.php now="2012-02-10 16:00:00" 

// Rectify the working directory to run from base folder
chdir(dirname(__FILE__));
chdir("../");


putenv("TZ=UTC");

if(isset($argv)){
	for($c=1;$c<count($argv);$c++){
        $it = explode("=",$argv[$c]);
        $_GET[$it[0]] = $it[1];
    }
}

$now = isset($_GET["now"]) ? $_GET["now"] : date("Y-m-d H:00:00");
$t = strtotime($now);
$st = $t - (4*3600);
$stime = date("Ymd",$st);
$shour = date("H",$st);
$iem_date = date("YmdHi",$st);
$model = "gfs";
$model2 = "gfs3";
$filename = "${model}.t${shour}z.bufrsnd.tar.gz";
// full path is important yo
$metdat = getcwd() . "/$model/metdat";
$fname = "${metdat}/${filename}";
$baseurl = "https://nomads.ncep.noaa.gov/pub/data/nccf/com";
$url = "${baseurl}/${model}/prod/${model}.${stime}/${shour}/${filename}";

if($shour == "06" || $shour == "18"){
	$model1 = "gfsm";
}
else{
	$model1 = "gfs";
}

// try to download tar ball containing bufr data to process
// attemps every miniute for ~3 hours
$j = 180;
while (! file_exists($fname)){
    echo "Attempting to download ${url}";
    system("wget -O ${fname} ${url}");
    if (! file_exists($fname)) {
        echo "File not there yet. Time: ".date("Y-m-d H:i:s")." UTC\n";
        sleep(60);
    }
	if($j == 0){
		die("Timed out!");
	}
    $j--;
}
system("tar -C ${metdat}/extracted -xzf ${fname}");
# system("rm ${fname}");

// generate list of files available
$files = preg_grep('/^([^.])/', scandir("${metdat}/extracted"));

// generate a dictionary of site IDs to station idenitifers
$sites = array();
$link = "bufrgruven/stations/gfs_bufrstations.txt";
$data = file($link);
foreach($data as $line){
	$d = explode(" ", trim(preg_replace( '/ +/', ' ', $line)));
	$sites[$d[0]] = strtolower($d[3]);
}

// rename gfs files, ex bufr.999330.2019081212 to bufr3.999330.2019081212
foreach($files as $f){
    $e = explode(".", $f);
    $oldfn = sprintf("%s/extracted/%s", $metdat, $f);
    $newfn = sprintf("%s/extracted/bufr3.%s.%s", $metdat, $e[1], $e[2]);
    rename($oldfn, $newfn);
}

$j = 0;
$count = sizeof($sites);
reset($sites);
while( list($site, $sid) = each($sites)){
    if ($sid != "ksdf") continue;
    $j++;
    $testfn = sprintf("%s/extracted/bufr3.%s.%s%s", $metdat, $site, $stime,
        $shour);
    if (! file_exists($testfn)){
        echo sprintf("gfs_bufkit file not found: %s", $testfn);
        continue;
    }
	echo sprintf("%04d/%04d Processing: %s (%s)...", $j, $count, $site, $sid);
    $output = Array();
    $cmd = "perl bufrgruven/bufr_gruven.pl --nfs --dset ${model} ".
        "--date ${stime} --cycle ${shour} --noascii ".
        "--metdat ${metdat} ".
        "--stations ${site} --nozipit";
    exec($cmd, $output, $exit_status);
    echo sprintf("%s\n", ($exit_status == 0)? 'Done': 'Error');
    $filename = "${metdat}/bufkit/${model}_${sid}.buf";
	if(file_exists($filename)){
        // -i use the product ID as the MD5 hash
        $cmd = "/home/meteor_ldm/bin/pqinsert -i -p 'bufkit ac ${iem_date} ".
            "bufkit/${model1}/${model2}_${sid}.buf ".
            "bufkit/${shour}/${model}/${model2}_${sid}.buf bogus' ${filename}";
		system($cmd);
	} else {
        echo sprintf("File: %s does not exist, so no LDM insert.\n".
            "cmd: %s\nbufrgruven.pl output: %s\n",
            $filename, $cmd, implode("\n", $output));
        exit("abort");
	}     
}

// final clean-up
system("rm ${metdat}/gempak/*");
system("rm ${metdat}/extracted/*");

// generate cobb data
// note: make_cobb.php inserts data into ldm
echo "Calling make_cobb.php\n";
system("php cobb/make_cobb.php iem_date=${iem_date} hour=${shour} model=${model}");

#system("rm ${metdat}/bufkit/*.buf");
#system("rm cobb/data/*.dat");

?>