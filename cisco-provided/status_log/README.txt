IRONPORT MAKES NO WARRANTIES, EXPRESS, IMPLIED OR STATUTORY, WITH RESPECT
TO THIS PACKAGE, INCLUDING WITHOUT LIMITATION ANY IMPLIED WARRANTY OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, NONINFRINGEMENT, OR
ARISING FROM COURSE OF PERFORMANCE, DEALING, USAGE OR TRADE. IRONPORT DOES
NOT PROVIDE ANY SUPPORT SERVICES FOR THIS PACKAGE.
===========================================================================


Example use:
============
tki-pbk:~/temp/diagram tcamp$ ./status.pl -conf graphthis.txt -js status.log 
Writing status-js-18557.html

tki-pbk:~/temp/diagram tcamp$ ./status.pl -csv -nojs status.log
No config file specified - setting up default graph.
Writing status-csv-18556.txt

tki-pbk:~/temp/diagram tcamp$ ./status.pl -csv -js-filename=statusout.html -conf graphthis.txt status.log
Writing status-csv-18562.txt
Writing statusout.html


With the default graphs configured to be created, the output HTML can be
about 23% of the size of the input.  Not small, and it can take a while
for the browser to load it.  As a matter of fact, Firefox 1.5 will display
a popup several times.  You can/should get rid of that by typing
'about:config' in the address bar.  Change 'dom.max_script_run_time' to 30.

If you want to change the graphs that are generated, you should modify the
contents of a text file and then use -conf to specify that configuration
file.

Registered things you can place in the conf file are:
'Delta Recipients Received'
'Delta Recipients Completed'
'Delta Messages in'
'Delta Messages Attempted'
'Delta Connections Attempted'
'CPULd'
'TotalLd'
'DskIO'
'RAMUtil'
'WorkQ'

an example conf file might contain these entries:

'Delta Messages in', 'Delta Recipients Received', 'WorkQ'
'TotalLd', 'RAMUtil'
'DskIO'

NOTES
=====
- CPULd is actually an indicator of the portion of CPU use associated with
  primarily the SMTP process.  To more accurately guage the total CPU usage
  occurring on a system, use TotalLd.
- The program does not attempt to reorder input files on the basis of their
  content's time.  So files provided out of order on the command-line will
  result in fairly useless output in the HTML case, and output in need of
  re-sorting in the CSV case.
- CSV output is written to file continually during fileparsing.  HTML output
  is written only at the end of the run, due to data collation and graph
  sizing requirements.  Ergo, too much input will blow out memory.


===========================================================================
This package is unaffiliated with, but makes direct use of the
JavaScript Diagram library created by Llutz Tautenhahn:
http://www.lutanho.net/diagram/
===========================================================================

