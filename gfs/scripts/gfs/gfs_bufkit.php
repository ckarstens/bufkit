<?php
// Rectify the working directory to always be three up from this script
echo dirname(__FILE__);
chdir(dirname(__FILE__));
chdir("../../..");

// Author: 	Chris Karstens
// Date: 	February 16, 2012
// Versions:	PHP, Perl, Bufrgruven
// Purpose:	1) Generate GFS bufkit profiles
//		2) Insert data into ldm archives
// Notes:	1) To run this script on the fly, issue the following command
// (specify date as model run time + 4 hours in UTC):
//		php gfs_bufkit.php now="2012-02-10 16:00:00" 

putenv("TZ=UTC");

if(isset($argv)){
	for($c=1;$c<count($argv);$c++){
        $it = explode("=",$argv[$c]);
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
$model = "gfs";
$model2 = "gfs3";
$filename = "".$model.".t".$shour."z.bufrsnd.tar.gz";
$filename2 = "".$model.".t".$shour."z.bufrsnd.tar";
$cur_dir = "${model}/scripts/${model}/";
$data_dir = "${model}/scripts/${model}/data/";
$fname = "${data_dir}${filename}";
$fname2 = "${data_dir}${filename2}";
$url = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/${model}/prod/${model}.${stime}/${shour}/${filename}";

if($shour == "06" || $shour == "18"){
	$model1 = "gfsm";
}
else{
	$model1 = "gfs";
}

// try to download tar ball containing bufr data to process
// attemps every miniute for one hour
$j = 180;
for($i=0;$i<=$j;$i++){
    system("wget -O ${fname} ${url}");
	echo "".$fname2."\n";
	system("gunzip ".$fname."");
    if(file_exists($fname2)){
        echo "File Found!\nTime: ".date("Y-m-d H:i:s")." UTC\n\n";
        system("tar -C ${data_dir} -xf ${fname2}");
        system("rm ${fname2}");
    break;
    }
    else{
        echo "File not there yet...\nTime: ".date("Y-m-d H:i:s")." UTC\n\n";
        system("rm ".$fname."");
        sleep(60);
    }
	if($i == $j){
		die("Timed out!");
	}
}

// generate list of files available
$files = preg_grep('/^([^.])/', scandir($data_dir));

// generate a dictionary of site IDs to station idenitifers
$sites = array();
$link = "gfs/stations/gfs_bufrstations.txt";
$data = file($link);
foreach($data as $line){
	$d = explode(" ", trim(preg_replace( '/ +/', ' ', $line)));
	$sites[$d[0]] = strtolower($d[3]);
}

// rename gfs files, ex bufr.999330.2019081212 to bufr3.999330.2019081212
foreach($files as $f){
	$e = explode(".", $f);
	system("mv ${data_dir}${f} ${data_dir}bufr3.{$e[1]}.{$e[2]}");
}

$j = 0;
$count = sizeof($sites);
reset($sites);
while( list($site, $sid) = each($sites)){
    // if ($sid != "ksdf") continue;
    $j++;
    $testfn = sprintf("%s/bufr3.%s.%s%s", $data_dir, $site, $stime, $shour);
    if (! file_exists($testfn)){
        echo sprintf("gfs_bufkit file not found: %s", $testfn);
        continue;
    }
	echo sprintf("%04d/%04d Processing: %s (%s)...", $j, $count, $site, $sid);
    $output = Array();
    exec("perl ${model}/bufr_gruven.pl --nfs --dset ${model} ".
        "--date ${stime} --cycle ${shour} --noascii ".
        "--stations ${site} --nozipit", $output, $exit_status);
    echo sprintf("%s\n", ($exit_status == 0)? 'Done': 'Error');
    $filename = "${model}/metdat/bufkit/${model}_${sid}.buf";
	if(file_exists($filename)){
		//system("python /local/ckarsten/bufkit/gfs/scripts/gfs/qpf_fixer.py ".$filename);
        // -i use the product ID as the MD5 hash
        $cmd = "/home/meteor_ldm/bin/pqinsert -i -p 'bufkit ac ${iem_date} ".
            "bufkit/${model1}/${model2}_${sid}.buf ".
            "bufkit/${shour}/${model}/${model2}_${sid}.buf bogus' ${filename}";
		system($cmd);
	} else {
        echo sprintf("File: %s does not exist, so no LDM insert. bufr_gruven output: %s\n",
            $filename, implode("\n", $output));
	}
	
    // the following block of code is needed, otherwise data processing
    // will terminate after about 60 or 70 files are processed.
	// I believe there is memory leakage occuring.
	if($j % 50 == 0){
        system("mv ${model}/metdat/bufkit/*.buf ${model}/metdat/bufkit_temp/");
		system("rm ${model}/metdat/bufr/*");
		system("rm ${model}/metdat/gempak/*");
    }        
}

// final clean-up
system("mv ${model}/metdat/bufkit/*.buf ${model}/metdat/bufkit_temp");
system("rm ${model}/metdat/bufr/*");
system("rm ${model}/metdat/gempak/*");
system("rm ${model}/scripts/${model}/data/*");

// generate cobb data
// note: make_cobb.php inserts data into ldm
echo "Calling make_cobb.php\n";
system("php ${model}/cobb/make_cobb.php iem_date=${iem_date} hour=${shour} model=${model}");

system("rm ${model}/metdat/bufkit_temp/*.buf");
system("rm ${model}/cobb/data/*.dat");

?>