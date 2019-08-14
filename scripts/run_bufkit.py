"""Proctor the exec of bufrgruven and cobb.

This is my life, controlling PHP and Perl scripts.
"""
import argparse
import os
import sys
import time
import subprocess

import requests
from tqdm import tqdm
from pyiem.util import logger, utc, exponential_backoff

LOG = logger()
BASEURL = "https://ftpprd.ncep.noaa.gov/data/nccf/com"
TEMPBASE = "/tmp"


def create_tempdirs(mybase, model, valid):
    """Generate our needed temp folders for running."""
    basedir = "%s/bufkit_%s_%s" % (mybase, model, valid.strftime("%Y%m%d%H"))
    if not os.path.isdir(basedir):
        os.makedirs(basedir)
    for subdir in [
            'ascii', 'bufkit', 'bufr', 'cobb', 'extracted', 'gempak', 'logs']:
        newdir = "%s/%s" % (basedir, subdir)
        if not os.path.isdir(newdir):
            os.makedirs(newdir)
    LOG.debug("Using %s has a temporary folder.", basedir)
    return basedir


def download_bufrsnd(tmpdir, model, valid, extra=''):
    """Get the file we need and save it."""
    # rap/prod/rap.20190814/rap.t00z.bufrsnd.tar.gz
    # gfs/prod/gfs.20190814/06/gfs.t06z.bufrsnd.tar.gz
    # nam/prod/nam.20190814/nam.t00z.tm00.bufrsnd.tar.gz
    model1 = model if model != 'nam4km' else 'nam'
    url = "%s/%s/prod/%s.%s/%s%s%s.t%02iz.%sbufrsnd%s.tar.gz" % (
        BASEURL, model1, model1, valid.strftime("%Y%m%d"),
        "%02i/" % (valid.hour, ) if model == 'gfs' else '',
        'conus/' if model == 'hrrr' else '',
        model1,
        valid.hour,
        "tm00." if model1 == 'nam' else '',
        extra
    )
    localfn = "%s/bufrsnd%s.tar.gz" % (tmpdir, extra)
    attempt = 1
    while not os.path.isfile(localfn) and attempt < 60:
        LOG.info("attempt %s at fetching %s", attempt, url)
        req = exponential_backoff(
            requests.get, url, timeout=60, stream=True)
        if req is None or req.status_code != 200:
            LOG.info(
                "download failed, sleeping 120s, response_code: %s",
                None if req is None else req.status_code)
            time.sleep(120)
        elif req and req.status_code == 200:
            with open(localfn, 'wb') as fh:
                for chunk in req.iter_content(chunk_size=1024):
                    if chunk:
                        fh.write(chunk)
        attempt += 1

    LOG.info("Extracting %s", localfn)
    subprocess.call(
        "tar -C %s/extracted -xzf %s" % (tmpdir, localfn), shell=True)


def load_stations(model):
    """Load up our station metadata and return xref."""
    fn = "bufrgruven/stations/%s_bufrstations.txt" % (model, )
    stations = {}
    with open(fn) as fh:
        for line in fh:
            tokens = line.split()
            if len(tokens) < 4:
                continue
            stations[tokens[0]] = tokens[3].lower()

    return stations


def run_bufrgruven(tmpdir, model, valid, sid, icao):
    """Run bufrgruven.pl please."""
    bufrfn = "%s/extracted/bufr.%s.%s" % (
        tmpdir, sid, valid.strftime("%Y%m%d%H"))
    if not os.path.isfile(bufrfn):
        LOG.info("%s not found for bufrgruven", bufrfn)
        return False
    # remove an already existing bufr file, if it is there
    fn = "%s/bufr/%s.%s.%s" % (tmpdir, model, sid, valid.strftime("%Y%m%d%H"))
    if os.path.isfile(fn):
        os.unlink(fn)
    cmd = (
        "perl bufrgruven/bufr_gruven.pl --dset %s "
        "--nfs %s/extracted/bufr.STNM.YYYYMMDDCC "
        "--date %s --cycle %02i --noascii "
        "--metdat %s "
        "--stations %s --nozipit"
    ) % (model, tmpdir, valid.strftime("%Y%m%d"), valid.hour, tmpdir, icao)
    proc = subprocess.Popen(
        cmd, shell=True, stderr=subprocess.PIPE, stdout=subprocess.PIPE)
    out, err = proc.communicate()
    if proc.returncode != 0:
        with open("%s/logs/%s.log" % (tmpdir, icao), 'w') as fh:
            fh.write("Cmd: %s\nStandard Out:\n%sStandard Err:\n%s" % (
                cmd, out.decode("ascii", "ignore"),
                err.decode('ascii', 'ignore')))
        return False
    # Remove GEMPAK Files as they seem to cause troubles if left laying around
    for suffix in ['sfc', 'snd', 'sfc_aux']:
        fn = "%s/gempak/%s_%s_bufr.%s" % (
            tmpdir, valid.strftime("%Y%m%d%H"), model, suffix)
        if os.path.isfile(fn):
            os.unlink(fn)
    return True


def run_cobb(tmpdir, model, icao):
    """Run cobb.pl please."""
    bufrfn = "%s/bufkit/%s_%s.buf" % (
        tmpdir, model, icao)
    if not os.path.isfile(bufrfn):
        return
    cmd = (
        "perl cobb/cobb.pl %s %s %s/bufkit"
    ) % (icao, model, tmpdir)
    proc = subprocess.Popen(
        cmd, shell=True, stderr=subprocess.PIPE, stdout=subprocess.PIPE)
    out, err = proc.communicate()
    result = out.decode('ascii')
    if proc.returncode != 0 or len(result) < 1000:
        with open("%s/logs/cobb_%s.log" % (tmpdir, icao), 'w') as fh:
            fh.write("Cmd: %s\nStandard Out:\n%sStandard Err:\n%s" % (
                cmd, out.decode("ascii", "ignore"),
                err.decode('ascii', 'ignore')))
    else:
        with open("%s/cobb/%s_%s.dat" % (tmpdir, model, icao), 'w') as fh:
            fh.write(result)


def insert_ldm_bufkit(tmpdir, model, valid, icao):
    """Send this product away for LTS."""
    filename = "%s/bufkit/%s_%s.buf" % (tmpdir, model, icao)
    if not os.path.isfile(filename):
        return
    model1 = "%s%s" % (
        model,
        "m" if valid.hour in [6, 18] and model in ['gfs', 'nam'] else '')
    model2 = "gfs3" if model == 'gfs' else model
    # place a 'cache-buster' LDM product name on the end as we are inserting
    # with -i, so the product name is used to compute the MD5
    cmd = (
        "/home/meteor_ldm/bin/pqinsert -i -p 'bufkit ac %s "
        "bufkit/%s/%s_%s.buf bufkit/%02i/%s/%s_%s.buf bogus%s' %s"
    ) % (
        valid.strftime("%Y%m%d%H%M"), model1, model2, icao, valid.hour,
        model, model2, icao, utc().strftime("%Y%m%d%H%M%S"), filename)
    proc = subprocess.Popen(
        cmd, shell=True, stderr=subprocess.PIPE, stdout=subprocess.PIPE)
    out, err = proc.communicate()
    if proc.returncode != 0:
        with open("%s/logs/ldmbufkit_%s.log" % (tmpdir, icao), 'w') as fh:
            fh.write("Standard Out:\n%sStandard Err:\n%s" % (
                out.decode("ascii", "ignore"), err.decode('ascii', 'ignore')))


def insert_ldm_cobb(tmpdir, model, valid, icao):
    """Send this product away for LTS."""
    filename = "%s/cobb/%s_%s.dat" % (tmpdir, model, icao)
    if not os.path.isfile(filename):
        return
    # place a 'cache-buster' LDM product name on the end as we are inserting
    # with -i, so the product name is used to compute the MD5
    cmd = (
        "/home/meteor_ldm/bin/pqinsert -i -p 'bufkit c %s "
        "cobb/%02i/%s/%s_%s.dat cobb/%02i/%s/%s_%s.dat bogus%s' %s"
    ) % (
        valid.strftime("%Y%m%d%H%M"), valid.hour, model, model, icao,
        valid.hour, model, model, icao, utc().strftime("%Y%m%d%H%M%S"),
        filename)
    proc = subprocess.Popen(
        cmd, shell=True, stderr=subprocess.PIPE, stdout=subprocess.PIPE)
    out, err = proc.communicate()
    if proc.returncode != 0:
        with open("%s/logs/ldmcobb_%s.log" % (tmpdir, icao), 'w') as fh:
            fh.write("Standard Out:\n%sStandard Err:\n%s" % (
                out.decode("ascii", "ignore"), err.decode('ascii', 'ignore')))


def delete_files(tmpdir, model, valid, sid, icao):
    """Need to cleanup after ourselves due to bufrgruven issues."""
    fn = "%s/bufkit/%s_%s.buf" % (tmpdir, model, icao)
    if os.path.isfile(fn):
        os.unlink(fn)
    fn = "%s/bufkit/%s.%s_%s.buf" % (
        tmpdir, valid.strftime("%Y%m%d%H"), model, icao)
    if os.path.isfile(fn):
        os.unlink(fn)
    fn = "%s/bufr/%s.%s.%s" % (
        tmpdir, model, sid, valid.strftime("%Y%m%d%H"))
    if os.path.isfile(fn):
        os.unlink(fn)


def rectify_cwd():
    """Make sure our CWD is okay."""
    mydir = os.sep.join(
        [os.path.dirname(os.path.abspath(__file__)), "../"])
    LOG.info("Setting cwd to %s", mydir)
    os.chdir(mydir)


def main():
    """Our Main Method."""
    parser = argparse.ArgumentParser(description='Generate BufKit+Cobb Data.')
    parser.add_argument(
        'model', help='model identifier to run this script for.')
    parser.add_argument('year', type=int, help='UTC Year')
    parser.add_argument('month', type=int, help='UTC Month')
    parser.add_argument('day', type=int, help='UTC Day')
    parser.add_argument('hour', type=int, help='UTC Hour')
    parser.add_argument(
        '--nocleanup', help='Leave temporary folder in-tact.',
        action='store_true'
    )
    parser.add_argument(
        "--tmpdir", default=TEMPBASE,
        help="Base directory to store temporary files."
    )

    args = parser.parse_args()
    model = args.model
    valid = utc(args.year, args.month, args.day, args.hour)
    LOG.info("Starting Up with args model: %s valid: %s", model, valid)

    # 0 need to rectify cwd to be the base of the repo folder
    rectify_cwd()
    # 1 Create metdat temp folder
    tmpdir = create_tempdirs(args.tmpdir, model, valid)
    # 2 Download files
    if model == 'nam4km':
        download_bufrsnd(tmpdir, model, valid, '_conusnest')
        download_bufrsnd(tmpdir, model, valid, '_alaskanest')
    else:
        download_bufrsnd(tmpdir, model, valid)
    # 3 Load station dictionary
    stations = load_stations(model)
    # 4 Run bufrgruven and cobb
    progress = tqdm(stations.items(), disable=not sys.stdout.isatty())
    for sid, icao in progress:
        progress.set_description(icao)
        if run_bufrgruven(tmpdir, model, valid, sid, icao):
            insert_ldm_bufkit(tmpdir, model, valid, icao)
            if model not in ['rap']:
                run_cobb(tmpdir, model, icao)
                insert_ldm_cobb(tmpdir, model, valid, icao)
            # Once we get > 1000 files in bufkit folder, bufrgruven bombs
            delete_files(tmpdir, model, valid, sid, icao)
    # 5. cleanup
    if not args.nocleanup:
        LOG.info("Blowing out tempdir: %s", tmpdir)
        subprocess.call("rm -rf %s" % (tmpdir, ), shell=True)

    LOG.info("Done.")


if __name__ == '__main__':
    main()
