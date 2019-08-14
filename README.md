BufKit and Cobb Proctor Script
==============================

This code proctors the generation of bufkit and cobb files.  These files are
found on the [BufKit Warehouse](https://www.meteor.iastate.edu/~ckarsten/bufkit/data/).

There is a single python script that proctors the job.  It should be called like so.

    python scripts/run_bufkit.py <model> <year> <month> <day> <hour>

There are two available options to that script, including ``--backfill``, which
tells the script to insert products into LDM such that downstream routing only
sends it to archive folders.  Another option is ``--nocleanup``, which leaves
most temporary files in-tact after job exists.  A final option is ``--tmpdir``,
which sets where the script should base temporary file storage.  This defaults
to `/tmp`.

RHEL8 Install Notes
-------------------

BufKit needs 32bit g2c library installed.  This is not available on RHEL8, but I
was able to copy `/usr/lib/libg2c.so.0` from a RHEL7 host and it appeared to
work just fine.  Additional RPM packages included:

    perl-Math-Complex perl-Time-HiRes
